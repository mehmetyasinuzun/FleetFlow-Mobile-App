import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:aracfilo/common/app_bars.dart';

class TumGecmisTurlarimEkran extends StatefulWidget {
  const TumGecmisTurlarimEkran({super.key});

  @override
  State<TumGecmisTurlarimEkran> createState() => _TumGecmisTurlarimEkranState();
}

class _TumGecmisTurlarimEkranState extends State<TumGecmisTurlarimEkran> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _allTours = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllTours();
  }

  Future<void> _loadAllTours() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final toursQuery = await _firestore
          .collection('tours')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('endTime', descending: true)
          .get();

      _allTours = toursQuery.docs.map((doc) => {
        'id': doc.id,
        ...doc.data()
      }).toList();

    } catch (e) {
      debugPrint('Tur verileri yükleme hatası: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: const PrimaryAppBar(
        title: 'Tüm Geçmiş Turlarım',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allTours.isEmpty
              ? _buildEmptyState()
              : _buildToursList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz tamamlanmış tur bulunmuyor',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'İlk turunuzu tamamladığınızda burada görünecek',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToursList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allTours.length,
      itemBuilder: (context, index) {
        final tour = _allTours[index];
        return _buildTourCard(tour, index);
      },
    );
  }

  Widget _buildTourCard(Map<String, dynamic> tour, int index) {
    final startTime = tour['startTime'] as Timestamp?;
    final endTime = tour['endTime'] as Timestamp?;
    final distance = tour['distance']?.toDouble() ?? 0.0;
    final duration = tour['duration'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.route,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tur ${_allTours.length - index}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (startTime != null)
                        Text(
                          DateFormat('dd MMMM yyyy', 'tr_TR').format(startTime.toDate()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tamamlandı',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  startTime != null && endTime != null
                      ? '${DateFormat('HH:mm').format(startTime.toDate())} - ${DateFormat('HH:mm').format(endTime.toDate())}'
                      : 'Süre bilgisi yok',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.straighten,
                    label: 'Mesafe',
                    value: '${distance.toStringAsFixed(1)} km',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.timer,
                    label: 'Süre',
                    value: _formatDuration(duration),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.speed,
                    label: 'Ort. Hız',
                    value: duration > 0 
                        ? '${(distance / (duration / 3600)).toStringAsFixed(0)} km/h'
                        : '0 km/h',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}s ${minutes}dk';
    } else {
      return '${minutes}dk';
    }
  }
}
