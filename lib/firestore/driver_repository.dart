import 'package:cloud_firestore/cloud_firestore.dart';

class DriverVehicle {
  final String id;
  final String plate;
  final String? model;
  DriverVehicle({required this.id, required this.plate, this.model});

  factory DriverVehicle.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    return DriverVehicle(
      id: d.id,
      plate: (data['plate'] as String?) ?? (data['plateNumber'] as String?) ?? 'Plaka Yok',
      model: data['model'] as String?,
    );
  }
}

class DriverTrip {
  final String id;
  final String driverId;
  final String vehicleId;
  final DateTime? startTime;
  final DateTime? endTime;
  final double? distanceKm;
  final double? avgSpeedKmh;
  final String status;

  DriverTrip({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    required this.startTime,
    required this.endTime,
    required this.distanceKm,
    required this.avgSpeedKmh,
    required this.status,
  });

  Duration get duration {
    final s = startTime;
    final e = endTime ?? DateTime.now();
    if (s == null) return Duration.zero;
    return e.difference(s);
  }

  factory DriverTrip.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    final tsStart = data['startTime'];
    final tsEnd = data['endTime'];
    return DriverTrip(
      id: d.id,
      driverId: (data['driverId'] as String?) ?? '',
      vehicleId: (data['vehicleId'] as String?) ?? '',
      startTime: tsStart is Timestamp ? tsStart.toDate() : null,
      endTime: tsEnd is Timestamp ? tsEnd.toDate() : null,
      distanceKm: (data['distanceKm'] as num?)?.toDouble(),
      avgSpeedKmh: (data['avgSpeedKmh'] as num?)?.toDouble() ?? double.nan,
      status: (data['status'] as String?) ?? 'completed',
    );
  }
}

class DriverRepository {
  DriverRepository._(this._db);
  static final DriverRepository instance = DriverRepository._(FirebaseFirestore.instance);
  final FirebaseFirestore _db;

  // Streams
  Stream<List<DriverVehicle>> streamAssignedVehicles(String uid) {
    return _db
        .collection('vehicles')
        .where('assignedTo', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => DriverVehicle.fromDoc(d)).toList());
  }

  Stream<DriverTrip?> streamActiveTrip(String uid) {
    // Basitleştirilmiş sorgu - indeks gerektirmez
    return _db
        .collection('trips')
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(10)
        .snapshots()
        .map((s) => s.docs.isEmpty ? null : DriverTrip.fromDoc(s.docs.first));
  }

  Stream<List<DriverTrip>> streamTodayTrips(String uid, DateTime todayStart) {
    // Basitleştirilmiş sorgu - indeks gerektirmez  
    return _db
        .collection('trips')
        .where('driverId', isEqualTo: uid)
        .limit(50)
        .snapshots()
        .map((s) => s.docs
            .map((d) => DriverTrip.fromDoc(d))
            .where((t) => t.startTime != null && t.startTime!.isAfter(todayStart))
            .toList()
            ..sort((a, b) => (b.startTime ?? DateTime(1970)).compareTo(a.startTime ?? DateTime(1970))));
  }

  // Writes
  Future<void> startTrip({required String uid, required String vehicleId}) async {
    final tripRef = _db.collection('trips').doc();
    await tripRef.set({
      'driverId': uid,
      'vehicleId': vehicleId,
      'startTime': FieldValue.serverTimestamp(),
      'status': 'active',
      'distanceKm': 0.0,
      'avgSpeedKmh': 0.0,
    });
  }

  Future<void> endTrip({required String tripId}) async {
    await _db.collection('trips').doc(tripId).update({
      'endTime': FieldValue.serverTimestamp(),
      'status': 'completed',
    });
  }
}
