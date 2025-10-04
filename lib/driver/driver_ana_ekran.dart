import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:aracfilo/common/app_bars.dart';
import 'package:aracfilo/common/theme/app_colors.dart';
import 'package:aracfilo/app_router/app_routes.dart';

class DriverAnaEkran extends StatefulWidget {
  const DriverAnaEkran({super.key});

  @override
  State<DriverAnaEkran> createState() => _DriverAnaEkranState();
}

class _DriverAnaEkranState extends State<DriverAnaEkran> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isTourActive = false;
  Map<String, dynamic>? _driverData;
  Map<String, dynamic>? _vehicleData;
  Map<String, dynamic>? _activeTourData;
  List<Map<String, dynamic>> _recentTours = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupDriverListener();
  }

  void _setupDriverListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Driver verilerindeki değişiklikleri dinle
    _firestore.collection('drivers').doc(user.uid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _driverData = snapshot.data();
        });
        
        // Eğer yeni vehicleId atanmışsa araç bilgilerini güncelle
        if (_driverData != null && 
            (_driverData!['vehicleId'] != null || _driverData!['assignedVehicleId'] != null)) {
          _loadVehicleData();
        }
      }
    });
  }

  Future<void> _loadVehicleData() async {
    if (_driverData == null) return;
    
    String? vehicleId = _driverData!['assignedVehicleId'] ?? _driverData!['vehicleId'];
    if (vehicleId != null) {
      try {
        final vehicleDoc = await _firestore.collection('vehicles').doc(vehicleId).get();
        if (vehicleDoc.exists) {
          setState(() {
            _vehicleData = vehicleDoc.data();
          });
        }
      } catch (e) {
        debugPrint('Araç bilgisi yüklenirken hata: $e');
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Sürücü bilgilerini çek
      final driverDoc = await _firestore.collection('drivers').doc(user.uid).get();
      if (driverDoc.exists) {
        _driverData = driverDoc.data();
      }

      // Kullanıcı bilgilerini çek (name ve fullName için)
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      String? userName;
      String? fullName;
      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        userName = userData['name'];
        fullName = userData['fullName'];
      }
      
      // Debug bilgisi
      debugPrint('🔍 Firestore Driver Data: $_driverData');
      debugPrint('🔍 Firestore User Name: $userName');
      debugPrint('🔍 Firestore User FullName: $fullName');
      debugPrint('🔍 Firebase Auth displayName: ${user.displayName}');
      
      // İsim öncelik sırası: users koleksiyonundaki fullName > name > displayName
      if (fullName != null && fullName.isNotEmpty) {
        _driverData ??= {};
        _driverData!['fullName'] = fullName;
      }
      
      if (userName != null && userName.isNotEmpty) {
        _driverData ??= {};
        _driverData!['userName'] = userName;
      }
      
      // Firebase Auth'dan displayName varsa ekle
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _driverData ??= {};
        _driverData!['displayName'] = user.displayName;
      }
        
      // Araç bilgilerini çek
      if (_driverData != null && _driverData!['vehicleId'] != null) {
        final vehicleDoc = await _firestore.collection('vehicles').doc(_driverData!['vehicleId']).get();
        if (vehicleDoc.exists) {
          _vehicleData = vehicleDoc.data();
        }
      }

      // Son turları çek (bugünkü veriler için)
      final DateTime today = DateTime.now();
      final DateTime startOfDay = DateTime(today.year, today.month, today.day);
      final DateTime endOfDay = DateTime(today.year, today.month, today.day + 1);
      
      final toursQuery = await _firestore
          .collection('tours')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .where('endTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('endTime', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('endTime', descending: true)
          .get();
      
      _recentTours = toursQuery.docs.map((doc) => {
        'id': doc.id,
        ...doc.data()
      }).toList();

      // Aktif tur var mı kontrol et
      final activeTourQuery = await _firestore
          .collection('tours')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();
      
      _isTourActive = activeTourQuery.docs.isNotEmpty;
      
      // Aktif tur verilerini sakla
      if (_isTourActive) {
        _activeTourData = {
          'id': activeTourQuery.docs.first.id,
          ...activeTourQuery.docs.first.data()
        };
      } else {
        _activeTourData = null;
      }
    } catch (e) {
      debugPrint('Veri yükleme hatası: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startTour() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('tours').add({
        'driverId': user.uid,
        'vehicleId': _driverData?['vehicleId'],
        'startTime': FieldValue.serverTimestamp(),
        'status': 'active',
        'distance': 0,
        'duration': 0,
      });

      setState(() => _isTourActive = true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tur başlatıldı')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _endTour() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Aktif turu bul ve bitir
      final activeTourQuery = await _firestore
          .collection('tours')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();

      if (activeTourQuery.docs.isNotEmpty) {
        final activeTour = activeTourQuery.docs.first;
        await activeTour.reference.update({
          'status': 'completed',
          'endTime': FieldValue.serverTimestamp(),
          'distance': 2.6, // Örnek mesafe - gerçekte GPS'den alınacak
          'duration': 265, // Örnek süre (4dk 25s = 265 saniye)
        });

        setState(() => _isTourActive = false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tur başarıyla tamamlandı')),
          );
        }

        // Verileri yeniden yükle
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tur bitirme hatası: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Çıkış yapılırken hata oluştu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.blue.shade400,
      appBar: PrimaryAppBar(
        title: 'Sürücü Paneli',
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Üst kısım - Sürücü kartı
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Merhaba,',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _driverData?['name'] ?? 
                    _driverData?['fullName'] ?? 
                    _driverData?['userName'] ?? 
                    _driverData?['displayName'] ?? 
                    _auth.currentUser?.displayName ?? 
                    'Sürücü',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.directions_car, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _getVehicleInfo(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Alt kısım - Beyaz alan
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tur başlatma bölümü
                    Center(
                      child: Column(
                        children: [
                          if (!_isTourActive) ...[
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                size: 40,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tur Başlatmaya Hazır',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Yeni bir tur başlatmak için önce araç seçin ve\nbutona dokunun',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _startTour,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  '▶ Tur Başlat',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            // Aktif Tur Arayüzü
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Aktif Tur',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'CANLI',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Column(
                                        children: [
                                          Text(
                                            'Başlangıç',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getStartTime(),
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          Text(
                                            'Süre',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getElapsedTime(),
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          Text(
                                            'Mesafe',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getCurrentDistance(),
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            // Haritayı aç
                                            Navigator.pushNamed(context, AppRoutes.mapScreen);
                                          },
                                          icon: Icon(Icons.map, color: Colors.green.shade700),
                                          label: Text(
                                            'Haritayı Aç',
                                            style: TextStyle(color: Colors.green.shade700),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            side: BorderSide(color: Colors.green.shade300),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _endTour,
                                          icon: const Icon(Icons.stop, color: Colors.white),
                                          label: const Text(
                                            'Turu Bitir',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Bugünkü özet
                    const Text(
                      'Bugünkü Özet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.route,
                            value: '${(_calculateTotalDistance()).toStringAsFixed(1)} km',
                            label: 'Toplam Mesafe',
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.flag,
                            value: '${_recentTours.length}',
                            label: 'Tur Sayısı',
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.access_time,
                            value: _formatTotalDuration(),
                            label: 'Toplam Süre',
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.speed,
                            value: '${(_calculateAverageSpeed()).toStringAsFixed(0)} km/h',
                            label: 'Ortalama Hız',
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Son turlar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bugün Yapılan Turlar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.driverTours);
                          },
                          child: const Text('Tümünü Gör'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _recentTours.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.info_outline, color: Colors.grey, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  'Bugün henüz tur verisi bulunmuyor',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: _recentTours.take(3).map((tour) => _buildTourCard(tour)).toList(),
                          ),

                    const SizedBox(height: 20),

                    // Alt butonlar
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, AppRoutes.driverTours);
                            },
                            icon: const Icon(Icons.history, color: Colors.white),
                            label: const Text('Geçmiş', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.warning, color: Colors.white),
                            label: const Text('Aktif Sefer', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Büyük Araç Talep butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.pushNamed(context, AppRoutes.vehicleRequest);
                          if (result != null) {
                            debugPrint('🚗 Seçilen araç: $result');
                            await _loadData();
                          }
                        },
                        icon: const Icon(Icons.directions_car, color: Colors.white, size: 24),
                        label: const Text(
                          'Araç Talep',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Profil ve Çıkış butonları
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Profil sayfasına yönlendir
                            },
                            icon: const Icon(Icons.person, color: Colors.white),
                            label: const Text('Profil', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE91E63), // Kırmızı-pembe ton
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.exit_to_app, color: Colors.white),
                            label: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTourCard(Map<String, dynamic> tour) {
    final startTime = tour['startTime'] as Timestamp?;
    final endTime = tour['endTime'] as Timestamp?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.route, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  startTime != null && endTime != null
                      ? '${DateFormat('HH:mm').format(startTime.toDate())} - ${DateFormat('HH:mm').format(endTime.toDate())}'
                      : 'Süre bilgisi yok',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${tour['distance']?.toStringAsFixed(1) ?? '0'} km • ${_formatDuration(tour['duration'] ?? 0)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  double _calculateTotalDistance() {
    return _recentTours.fold(0.0, (total, tour) => total + (tour['distance']?.toDouble() ?? 0.0));
  }

  double _calculateAverageSpeed() {
    if (_recentTours.isEmpty) return 0.0;
    
    double totalDistance = _calculateTotalDistance();
    int totalDuration = _recentTours.fold(0, (total, tour) => total + ((tour['duration'] as int?) ?? 0));
    
    if (totalDuration == 0) return 0.0;
    
    return (totalDistance / (totalDuration / 3600)); // km/h
  }

  String _formatTotalDuration() {
    int totalSeconds = _recentTours.fold(0, (total, tour) => total + ((tour['duration'] as int?) ?? 0));
    return _formatDuration(totalSeconds);
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

  // Aktif tur için yardımcı fonksiyonlar
  String _getStartTime() {
    if (_activeTourData?['startTime'] != null) {
      final startTime = (_activeTourData!['startTime'] as Timestamp).toDate();
      return DateFormat('HH:mm').format(startTime);
    }
    return '00:00';
  }

  String _getElapsedTime() {
    if (_activeTourData?['startTime'] != null) {
      final startTime = (_activeTourData!['startTime'] as Timestamp).toDate();
      final now = DateTime.now();
      final elapsed = now.difference(startTime);
      
      int minutes = elapsed.inMinutes;
      int seconds = elapsed.inSeconds % 60;
      
      return '${minutes}dk ${seconds}s';
    }
    return '0dk 0s';
  }

  String _getCurrentDistance() {
    final distance = _activeTourData?['distance']?.toDouble() ?? 0.0;
    return '${distance.toStringAsFixed(1)} km';
  }

  String _getVehicleInfo() {
    // Önce driver'da assignedVehicleId kontrol et
    if (_driverData != null && _driverData!['assignedVehicleId'] != null) {
      final vehicleId = _driverData!['assignedVehicleId'];
      return 'Araç bilgisi: $vehicleId';
    }
    
    if (_vehicleData != null) {
      final plate = _vehicleData!['plateNumber'] ?? _vehicleData!['plate'] ?? 'Bilinmiyor';
      final brand = _vehicleData!['brand'] ?? '';
      final model = _vehicleData!['model'] ?? '';
      
      if (brand.isNotEmpty && model.isNotEmpty) {
        return 'Atanmış Araç: $plate ($brand $model)';
      } else {
        return 'Atanmış Araç: $plate';
      }
    } else if (_driverData != null && (_driverData!['vehicleId'] != null || _driverData!['assignedVehicleId'] != null)) {
      return 'Araç bilgileri yükleniyor...';
    } else {
      return 'Araç seçmek için araç talebine gidin';
    }
  }
}