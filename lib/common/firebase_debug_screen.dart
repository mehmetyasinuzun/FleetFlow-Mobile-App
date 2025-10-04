import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseDebugScreen extends StatefulWidget {
  const FirebaseDebugScreen({Key? key}) : super(key: key);

  @override
  State<FirebaseDebugScreen> createState() => _FirebaseDebugScreenState();
}

class _FirebaseDebugScreenState extends State<FirebaseDebugScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Map<String, dynamic>? userData;
  Map<String, dynamic>? driverData;
  Map<String, dynamic>? vehicleData;
  List<Map<String, dynamic>> tourData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      print('🔍 Debug: User ID: ${user.uid}');
      print('📧 Debug: User Email: ${user.email}');

      // Load user data
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          userData = userDoc.data();
          print('✅ User data found: $userData');
        } else {
          print('❌ User document not found');
        }
      } catch (e) {
        print('💥 User data error: $e');
      }

      // Load driver data
      try {
        final driverDoc = await _firestore.collection('drivers').doc(user.uid).get();
        if (driverDoc.exists) {
          driverData = driverDoc.data();
          print('✅ Driver data found: $driverData');
        } else {
          print('❌ Driver document not found');
        }
      } catch (e) {
        print('💥 Driver data error: $e');
      }

      // Load vehicle data
      try {
        if (driverData?['assignedVehicleId'] != null) {
          final vehicleDoc = await _firestore
              .collection('vehicles')
              .doc(driverData!['assignedVehicleId'])
              .get();
          if (vehicleDoc.exists) {
            vehicleData = vehicleDoc.data();
            print('✅ Vehicle data found: $vehicleData');
          } else {
            print('❌ Vehicle document not found');
          }
        }
      } catch (e) {
        print('💥 Vehicle data error: $e');
      }

      // Load tour data
      try {
        final tourQuery = await _firestore
            .collection('tours')
            .where('driverId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();
        
        tourData = tourQuery.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
        
        print('✅ Tour data found: ${tourData.length} tours');
      } catch (e) {
        print('💥 Tour data error: $e');
      }

    } catch (e) {
      print('💥 General error: $e');
    }

    setState(() => isLoading = false);
  }

  Future<void> _createTestData() async {
    try {
      final user = _auth.currentUser;
      if (user?.email == 'yasin@gmail.com') {
        
        // Create user data
        await _firestore.collection('users').doc(user!.uid).set({
          'email': 'yasin@gmail.com',
          'firstName': 'Yasin',
          'lastName': 'Sürücü',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Create driver data
        await _firestore.collection('drivers').doc(user.uid).set({
          'email': 'yasin@gmail.com',
          'assignedVehicleId': 'yasin_vehicle_001',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Create vehicle data
        await _firestore.collection('vehicles').doc('yasin_vehicle_001').set({
          'plateNumber': '58 AAA 333',
          'model': 'Test Araç',
          'year': 2024,
          'assignedTo': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test verisi oluşturuldu!')),
        );

        _loadAllData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Firebase Debug'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadAllData,
            icon: Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _createTestData,
            icon: Icon(Icons.add),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentUserCard(),
                  SizedBox(height: 16),
                  _buildDataCard('User Data', userData),
                  SizedBox(height: 16),
                  _buildDataCard('Driver Data', driverData),
                  SizedBox(height: 16),
                  _buildDataCard('Vehicle Data', vehicleData),
                  SizedBox(height: 16),
                  _buildTourCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentUserCard() {
    final user = _auth.currentUser;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current User',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('UID: ${user?.uid ?? 'No user'}'),
            Text('Email: ${user?.email ?? 'No email'}'),
            Text('Display Name: ${user?.displayName ?? 'No name'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(String title, Map<String, dynamic>? data) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: data != null ? Colors.green : Colors.red,
              ),
            ),
            SizedBox(height: 8),
            if (data != null)
              ...data.entries.map((entry) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('${entry.key}: ${entry.value}'),
              ))
            else
              Text(
                'No data found',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTourCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tour Data (${tourData.length} tours)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: tourData.isNotEmpty ? Colors.green : Colors.orange,
              ),
            ),
            SizedBox(height: 8),
            if (tourData.isEmpty)
              Text(
                'No tours found',
                style: TextStyle(color: Colors.orange),
              )
            else
              ...tourData.take(3).map((tour) => Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${tour['id']}'),
                    Text('Status: ${tour['status'] ?? 'Unknown'}'),
                    Text('Driver ID: ${tour['driverId'] ?? 'Unknown'}'),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
}