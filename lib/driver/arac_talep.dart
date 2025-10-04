import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AracTalepScreen extends StatefulWidget {
  const AracTalepScreen({Key? key}) : super(key: key);

  @override
  State<AracTalepScreen> createState() => _AracTalepScreenState();
}

class _AracTalepScreenState extends State<AracTalepScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? selectedVehicleId;
  bool isLoading = false;

  // Örnek araç listesi (şimdilik sabit, sonra Firebase'den çekilecek)
  final List<Map<String, dynamic>> vehicles = [
    {
      'id': 'vehicle_001',
      'plateNumber': '34 ABC 123',
      'model': 'Mercedes Sprinter',
      'year': 2023,
      'type': 'Minibüs',
      'capacity': '16 Kişi',
      'color': 'Beyaz',
      'available': true,
    },
    {
      'id': 'vehicle_002', 
      'plateNumber': '06 DEF 456',
      'model': 'Ford Transit',
      'year': 2022,
      'type': 'Minibüs',
      'capacity': '14 Kişi',
      'color': 'Gri',
      'available': true,
    },
    {
      'id': 'vehicle_003',
      'plateNumber': '35 GHI 789',
      'model': 'Volkswagen Crafter',
      'year': 2024,
      'type': 'Minibüs', 
      'capacity': '17 Kişi',
      'color': 'Mavi',
      'available': false,
    },
    {
      'id': 'vehicle_004',
      'plateNumber': '16 JKL 012',
      'model': 'Iveco Daily',
      'year': 2023,
      'type': 'Minibüs',
      'capacity': '19 Kişi',
      'color': 'Kırmızı',
      'available': true,
    },
    {
      'id': 'vehicle_005',
      'plateNumber': '58 AAA 333',
      'model': 'Test Araç',
      'year': 2024,
      'type': 'Minibüs',
      'capacity': '15 Kişi', 
      'color': 'Siyah',
      'available': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Araç Seçin'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Header Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                Icon(
                  Icons.directions_car,
                  color: Colors.blue.shade600,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Kullanılabilir Araçlar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Size uygun aracı seçin',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Vehicle List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                return _buildVehicleCard(vehicle);
              },
            ),
          ),
          
          // Action Buttons
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: const Text(
                      'İptal',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedVehicleId != null && !isLoading
                        ? _assignVehicle
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Seç',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    final isSelected = selectedVehicleId == vehicle['id'];
    final isAvailable = vehicle['available'] == true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected
              ? Colors.blue.shade600
              : (isAvailable ? Colors.grey.shade300 : Colors.red.shade300),
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isSelected
            ? Colors.blue.shade50
            : (isAvailable ? Colors.white : Colors.grey.shade50),
      ),
      child: InkWell(
        onTap: isAvailable ? () => _selectVehicle(vehicle['id']) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Vehicle Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAvailable 
                      ? Colors.blue.shade100 
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.directions_bus,
                  color: isAvailable 
                      ? Colors.blue.shade600 
                      : Colors.grey.shade400,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Vehicle Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          vehicle['plateNumber'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? Colors.black : Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        if (!isAvailable)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Kullanımda',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vehicle['model']} (${vehicle['year']})',
                      style: TextStyle(
                        fontSize: 14,
                        color: isAvailable ? Colors.grey.shade700 : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 16,
                          color: isAvailable ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          vehicle['capacity'],
                          style: TextStyle(
                            fontSize: 12,
                            color: isAvailable ? Colors.grey.shade600 : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.palette,
                          size: 16,
                          color: isAvailable ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          vehicle['color'],
                          style: TextStyle(
                            fontSize: 12,
                            color: isAvailable ? Colors.grey.shade600 : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Selection Indicator
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectVehicle(String vehicleId) {
    setState(() {
      selectedVehicleId = vehicleId;
    });
  }

  Future<void> _assignVehicle() async {
    if (selectedVehicleId == null) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı girişi yapılmamış');
      }

      final selectedVehicle = vehicles.firstWhere(
        (vehicle) => vehicle['id'] == selectedVehicleId,
      );

      debugPrint('🚗 Araç atanıyor: ${selectedVehicle['plateNumber']}');

      // Update driver's assigned vehicle
      await _firestore.collection('drivers').doc(user.uid).set({
        'email': user.email,
        'assignedVehicleId': selectedVehicleId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Create or update vehicle document
      await _firestore.collection('vehicles').doc(selectedVehicleId).set({
        'plateNumber': selectedVehicle['plateNumber'],
        'model': selectedVehicle['model'],
        'year': selectedVehicle['year'],
        'type': selectedVehicle['type'],
        'capacity': selectedVehicle['capacity'],
        'color': selectedVehicle['color'],
        'assignedTo': user.uid,
        'available': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Araç başarıyla atandı');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selectedVehicle['plateNumber']} plakalı araç size atandı!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Return selected vehicle info to previous screen  
      Navigator.pop(context, selectedVehicle);

    } catch (e) {
      debugPrint('💥 Araç atama hatası: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Araç atama hatası: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}
