import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Debug flags for map troubleshooting - make _enableMapDebug non-const for settings
  bool _enableMapDebug = true;
  static const bool _enableLocationDebug = true;
  static const bool _enableRoadDebug = true;

  // Location tracking
  Position? _currentPosition;
  Position? _lastPosition;
  StreamSubscription<Position>? _positionStream;

  // Tour data
  Map<String, dynamic>? _activeTourData;
  String _driverName = '';
  String _vehiclePlate = '';
  LatLng? _lastKnownLocation;
  
  // Real-time tracking data
  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _averageSpeed = 0.0;
  double _totalDistance = 0.0;
  Duration _elapsedTime = Duration.zero;
  Timer? _timer;

  // UI state  
  bool _isBottomSheetExpanded = true;
  late AnimationController _bottomSheetController;
  late Animation<double> _bottomSheetAnimation;
  
  // Map settings
  bool _zoomControlsEnabled = false;
  bool _myLocationButtonEnabled = false;
  bool _compassEnabled = true;
  bool _trafficEnabled = true;
  bool _buildingsEnabled = true;
  double _currentZoom = 15.0;
  MapType _currentMapType = MapType.normal;
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 MapScreen initState başlatıldı');
    _checkGooglePlayServices();
    _initializeAnimations();
    _loadTourData();
    _loadLastKnownLocation();
    _initializeLocation();
    _startTimer();
    debugPrint('🚀 MapScreen initState tamamlandı');
  }
  
  Future<void> _checkGooglePlayServices() async {
    debugPrint('🔍 Google Play Services kontrol ediliyor...');
    debugPrint('🔑 Yeni API Key kullanılıyor: AIzaSyCGGUfg_VobsXaFsBTIoSfHIS_hEalK7BE');
    try {
      // Google Services mevcut mu kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('📍 Location service: $serviceEnabled');
      
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('🔐 Location permission: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('🔐 Permission requested: $permission');
      }
      
      debugPrint('✅ Google Services kontrol tamamlandı');
    } catch (e) {
      debugPrint('❌ Google Services hatası: $e');
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _timer?.cancel();
    _bottomSheetController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _bottomSheetController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bottomSheetAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bottomSheetController,
      curve: Curves.easeInOut,
    ));
    _bottomSheetController.forward();
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    if (_enableLocationDebug) debugPrint('🔧 Konum başlatılıyor...');

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (_enableLocationDebug) debugPrint('📍 Location service enabled: $serviceEnabled');
    
    if (!serviceEnabled) {
      if (_enableLocationDebug) debugPrint('❌ Konum servisi kapalı');
      _showLocationError('Lütfen telefon ayarlarından konum servisini açın.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (_enableLocationDebug) debugPrint('📍 Current permission: $permission');
    
    if (permission == LocationPermission.denied) {
      if (_enableLocationDebug) debugPrint('📍 Requesting permission...');
      permission = await Geolocator.requestPermission();
      if (_enableLocationDebug) debugPrint('📍 Permission after request: $permission');
      
      if (permission == LocationPermission.denied) {
        if (_enableLocationDebug) debugPrint('❌ Konum izni reddedildi');
        _showLocationError('Konum izni reddedildi.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (_enableLocationDebug) debugPrint('❌ Konum izni kalıcı olarak reddedildi');
      _showLocationError('Konum izni kalıcı olarak reddedildi. Lütfen ayarlardan açın.');
      return;
    }

    if (_enableLocationDebug) debugPrint('✅ Konum izinleri tamam, ilk pozisyon alınıyor...');
    
    // Get current position
    await _getCurrentPosition();
    
    // Start listening to position changes
    _startLocationTracking();
  }

  Future<void> _loadLastKnownLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && 
            data['lastLatitude'] != null && 
            data['lastLongitude'] != null) {
          _lastKnownLocation = LatLng(
            data['lastLatitude'].toDouble(),
            data['lastLongitude'].toDouble(),
          );
          debugPrint('📍 Son bilinen konum yüklendi: ${_lastKnownLocation}');
        }
      }
    } catch (e) {
      debugPrint('❌ Son konum yüklenirken hata: $e');
    }
  }

  Future<void> _saveLastKnownLocation(Position position) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .update({
        'lastLatitude': position.latitude,
        'lastLongitude': position.longitude,
        'lastLocationTime': FieldValue.serverTimestamp(),
      });
      
      debugPrint('💾 Son konum kaydedildi: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('❌ Son konum kaydedilirken hata: $e');
    }
  }

  Future<void> _getCurrentPosition() async {
    try {
      if (_enableLocationDebug) debugPrint('📍 Konum alınıyor...');
      
      // Check permissions first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (_enableLocationDebug) debugPrint('❌ Konum izni reddedildi kalıcı olarak');
        _showLocationError('Konum izni gerekli. Lütfen ayarlardan açın.');
        return;
      }
      
      if (permission == LocationPermission.denied) {
        if (_enableLocationDebug) debugPrint('❌ Konum izni reddedildi');
        _showLocationError('Konum izni gerekli.');
        return;
      }
      
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (_enableLocationDebug) debugPrint('❌ Konum servisi kapalı');
        _showLocationError('Lütfen konum servisini açın.');
        return;
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
      
      if (_enableLocationDebug) debugPrint('✅ Konum alındı: ${position.latitude}, ${position.longitude}');
      
      setState(() {
        _lastPosition = _currentPosition;
        _currentPosition = position;
        double newSpeed = position.speed * 3.6; // m/s to km/h
        _updateSpeedTracking(newSpeed);
      });

      _updateMapPosition(position);
      _updateFirebaseLocation(position);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Konum güncellendi'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
    } catch (e) {
      if (_enableLocationDebug) debugPrint('💥 Konum alma hatası: $e');
      _showLocationError('Konum alınamadı: $e');
    }
  }
  
  void _showLocationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      setState(() {
        _lastPosition = _currentPosition;
        _currentPosition = position;
        double newSpeed = position.speed * 3.6; // m/s to km/h
        _updateSpeedTracking(newSpeed);
      });

      _updateMapPosition(position);
      _updateFirebaseLocation(position);
      _calculateDistance(position);
      _updateRoute(position);
      
      // Son konumu kaydet
      _saveLastKnownLocation(position);
    });
  }

  void _updateMapPosition(Position position) {
    final newLatLng = LatLng(position.latitude, position.longitude);
    
    if (_enableMapDebug) debugPrint('🗺️ Harita güncelleniyor: ${position.latitude}, ${position.longitude}');
    
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: newLatLng,
          infoWindow: InfoWindow(
            title: 'Mevcut Konumum',
            snippet: 'Hız: ${_currentSpeed.toStringAsFixed(1)} km/h',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      };
    });

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: newLatLng,
            zoom: 16.0,
            tilt: 0.0,  // Keep map flat for better road visibility
            bearing: 0.0,  // North up orientation
          ),
        ),
      );
      if (_enableMapDebug) debugPrint('✅ Kamera güncellendi - zoom: 16.0, tilt: 0.0');
    } else {
      if (_enableMapDebug) debugPrint('❌ Map controller null - kamera güncellenemedi');
    }
  }

  void _updateRoute(Position position) {
    final newLatLng = LatLng(position.latitude, position.longitude);
    
    if (_enableRoadDebug) debugPrint('🛣️ Route güncelleniyor - yeni nokta: ${newLatLng.latitude}, ${newLatLng.longitude}');
    
    setState(() {
      _routePoints.add(newLatLng);
      
      if (_enableRoadDebug) debugPrint('🛣️ Toplam route noktası: ${_routePoints.length}');
      
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: Colors.blue,
          width: 4,
          patterns: [],
        ),
      };
    });
    
    if (_enableRoadDebug) debugPrint('✅ Polyline güncellendi');
  }

  Future<void> _updateFirebaseLocation(Position position) async {
    try {
      final user = _auth.currentUser;
      if (user == null || _activeTourData == null) return;

      await _firestore.collection('tours').doc(_activeTourData!['id']).update({
        'currentLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': position.speed,
          'heading': position.heading,
          'accuracy': position.accuracy,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'currentSpeed': position.speed * 3.6,
        'totalDistance': _totalDistance,
        'elapsedTime': _elapsedTime.inMinutes,
        'route': _routePoints.map((point) => {
          'lat': point.latitude,
          'lng': point.longitude,
        }).toList(),
      });
    } catch (e) {
      debugPrint('Firebase konum güncelleme hatası: $e');
    }
  }

  void _calculateDistance(Position newPosition) {
    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );
      
      setState(() {
        _totalDistance += distance / 1000; // meters to kilometers
      });
    }
  }

  Future<void> _loadTourData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ User null - giriş yapılmamış');
        return;
      }

      debugPrint('🔍 User ID: ${user.uid}');
      debugPrint('📧 User Email: ${user.email}');

      // Get active tour
      final tourQuery = await _firestore
          .collection('tours')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      debugPrint('🚗 Active tour count: ${tourQuery.docs.length}');

      if (tourQuery.docs.isNotEmpty) {
        final tourData = tourQuery.docs.first.data();
        _activeTourData = {
          'id': tourQuery.docs.first.id,
          ...tourData,
        };

        debugPrint('✅ Active tour found: ${_activeTourData!['id']}');

        // Load existing route if available
        if (tourData['route'] != null) {
          final routeData = List<Map<String, dynamic>>.from(tourData['route']);
          _routePoints = routeData.map((point) => 
            LatLng(point['lat'].toDouble(), point['lng'].toDouble())
          ).toList();
        }

        // Load existing distance and time
        _totalDistance = (tourData['totalDistance'] ?? 0.0).toDouble();
        _elapsedTime = Duration(minutes: (tourData['elapsedTime'] ?? 0).toInt());
      } else {
        debugPrint('❌ Active tour bulunamadı');
      }

      // Get driver info - E-mail ile de arama yapalım
      DocumentSnapshot? driverDoc;
      Map<String, dynamic>? driverData;

      // Önce UID ile arama
      driverDoc = await _firestore.collection('drivers').doc(user.uid).get();
      
      if (!driverDoc.exists) {
        debugPrint('❌ Driver UID ile bulunamadı, e-mail ile arıyorum...');
        
        // E-mail ile arama
        final driverQuery = await _firestore
            .collection('drivers')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
            
        if (driverQuery.docs.isNotEmpty) {
          driverDoc = driverQuery.docs.first;
          debugPrint('✅ Driver e-mail ile bulundu');
        }
      }

      if (driverDoc.exists) {
        driverData = driverDoc.data() as Map<String, dynamic>;
        debugPrint('✅ Driver data: $driverData');
        
        // Get user name - E-mail ile de arama
        DocumentSnapshot? userDoc;
        
        userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (!userDoc.exists) {
          final userQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();
              
          if (userQuery.docs.isNotEmpty) {
            userDoc = userQuery.docs.first;
          }
        }
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          _driverName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
          if (_driverName.isEmpty) {
            _driverName = userData['name'] ?? 'Sürücü';
          }
          debugPrint('👤 Driver name: $_driverName');
        }

        // Get vehicle info - Mehrere Felder versuchen
        String? vehicleId = driverData['assignedVehicleId'] ?? 
                           driverData['vehicleId'] ?? 
                           driverData['vehicle_id'];
        
        debugPrint('🚙 Vehicle ID: $vehicleId');
        
        if (vehicleId != null) {
          final vehicleDoc = await _firestore
              .collection('vehicles')
              .doc(vehicleId)
              .get();
          
          if (vehicleDoc.exists) {
            final vehicleData = vehicleDoc.data()!;
            _vehiclePlate = vehicleData['plateNumber'] ?? 
                          vehicleData['plate'] ?? 
                          vehicleData['licensePlate'] ?? 
                          'Bilinmiyor';
            debugPrint('🏷️ Vehicle plate: $_vehiclePlate');
          } else {
            debugPrint('❌ Vehicle document bulunamadı: $vehicleId');
          }
        } else {
          debugPrint('❌ assignedVehicleId null');
        }
      } else {
        debugPrint('❌ Driver document bulunamadı');
      }

      setState(() {});
      debugPrint('🔄 UI Updated - Name: $_driverName, Plate: $_vehiclePlate');
    } catch (e) {
      debugPrint('💥 Tur verisi yükleme hatası: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime = Duration(seconds: _elapsedTime.inSeconds + 1);
      });
    });
  }

  void _toggleBottomSheet() {
    setState(() {
      _isBottomSheetExpanded = !_isBottomSheetExpanded;
    });
    
    if (_isBottomSheetExpanded) {
      _bottomSheetController.forward();
    } else {
      _bottomSheetController.reverse();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 MapScreen build metodu çağrıldı');
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              debugPrint('🗺️ Google Map oluşturuldu - Controller alındı');
              _mapController = controller;
              debugPrint('🗺️ Map controller başarıyla atandı');
              
              if (_currentPosition != null) {
                debugPrint('🗺️ Mevcut konuma hareket ediliyor: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
                _updateMapPosition(_currentPosition!);
              } else {
                debugPrint('⚠️ Mevcut konum null, varsayılan konumda kalınıyor');
              }
              
              // Map yüklendikten sonra raster tile'ları kontrol et
              debugPrint('🗺️ Map controller hazır - API bağlantısı test ediliyor');
            },
            initialCameraPosition: CameraPosition(
              target: _lastKnownLocation ?? const LatLng(41.0082, 28.9784), // Son konum veya İstanbul merkez
              zoom: _currentZoom,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: _myLocationButtonEnabled,
            zoomControlsEnabled: _zoomControlsEnabled,
            compassEnabled: _compassEnabled,
            markers: _markers,
            polylines: _polylines,
            mapType: _currentMapType,
            trafficEnabled: _trafficEnabled,
            buildingsEnabled: _buildingsEnabled,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            zoomGesturesEnabled: true,
            liteModeEnabled: false,  // Disable lite mode for full features
            onCameraMove: (CameraPosition position) {
              if (_enableMapDebug && _enableRoadDebug) {
                debugPrint('📹 Camera moved to: ${position.target.latitude}, ${position.target.longitude}, zoom: ${position.zoom}');
              }
            },
            onCameraIdle: () {
              if (_enableMapDebug && _enableRoadDebug) {
                debugPrint('📹 Camera movement finished');
              }
            },
            onTap: (LatLng latLng) {
              if (_enableMapDebug) debugPrint('👆 Map tapped at: ${latLng.latitude}, ${latLng.longitude}');
            },
          ),
          
          // Left Floating Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          
          // Center Floating Vehicle Info
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 88, // Left button width + margin
            right: 88, // Right button width + margin
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _vehiclePlate.isEmpty ? '34 ABC 123' : _vehiclePlate,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Araç Detayları',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Right Floating Menu Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 24,
                ),
                onSelected: (value) {
                  if (value == 'end_tour') {
                    _endTour();
                  } else if (value == 'settings') {
                    _showSettings();
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'end_tour',
                    child: Row(
                      children: [
                        Icon(Icons.stop_circle, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Turu Bitir'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings, color: Colors.grey),
                        SizedBox(width: 12),
                        Text('Ayarlar'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Floating Speed and Distance Widget - Like in the image
          Positioned(
            bottom: 100, // Position above the bottom panel
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95), // Semi-transparent white
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Speed Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mevcut Hız',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_currentSpeed.toStringAsFixed(1)} km/h',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '(${(_currentSpeed / 3.6).toStringAsFixed(2)} m/s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Divider
                  Container(
                    height: 60,
                    width: 1,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  
                  // Distance Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Toplam Mesafe',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_totalDistance.toStringAsFixed(2)} km',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16), // Space for alignment
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Floating Panel - Simple version like original
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: _toggleBottomSheet,
              child: AnimatedBuilder(
                animation: _bottomSheetAnimation,
                builder: (context, child) {
                  return Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        
                        // Always visible summary - Simple speed and distance
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildQuickStat(
                                'Mevcut Hız',
                                '${_currentSpeed.toStringAsFixed(1)} km/h',
                                Icons.speed,
                                Colors.blue,
                              ),
                              _buildQuickStat(
                                'Toplam Mesafe',
                                '${_totalDistance.toStringAsFixed(2)} km',
                                Icons.straighten,
                                Colors.green,
                              ),
                            ],
                          ),
                        ),
                        
                        // Expandable content
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: _isBottomSheetExpanded 
                              ? 200 * _bottomSheetAnimation.value
                              : 0,
                          child: SingleChildScrollView(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                children: [
                                  const Divider(),
                                  
                                  // Detailed stats
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDetailStat(
                                          'Süre',
                                          _formatDuration(_elapsedTime),
                                          Icons.timer,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildDetailStat(
                                          'Ort. Hız',
                                          '${_averageSpeed.toStringAsFixed(1)} km/h',
                                          Icons.trending_up,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildDetailStat(
                                          'Maks. Hız',
                                          '${_maxSpeed.toStringAsFixed(1)} km/h',
                                          Icons.speed,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        // Remove expandable content - keep only essential info
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _enableMapDebug ? Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            mini: true,
            heroTag: "debug_info",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('🔧 Harita Debug Bilgileri'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🗺️ Map Controller: ${_mapController != null ? "✅ Var" : "❌ Yok"}'),
                        Text('📍 Current Position: ${_currentPosition != null ? "✅ ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}" : "❌ Yok"}'),
                        Text('🎯 Markers: ${_markers.length} adet'),
                        Text('🛣️ Route Points: ${_routePoints.length} nokta'),
                        Text('📏 Polylines: ${_polylines.length} çizgi'),
                        Text('👤 Driver: $_driverName'),
                        Text('🚙 Vehicle: $_vehiclePlate'),
                        Text('⚡ Speed: ${_currentSpeed.toStringAsFixed(1)} km/h'),
                        if (_activeTourData != null)
                          Text('🎯 Active Tour: ${_activeTourData!['id'] ?? "Bilinmiyor"}'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Kapat'),
                    ),
                  ],
                ),
              );
            },
            child: Icon(Icons.info),
            backgroundColor: Colors.orange,
          ),
          SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            heroTag: "force_location",
            onPressed: () {
              if (_enableLocationDebug) debugPrint('🔧 Manual location refresh triggered');
              _getCurrentPosition();
            },
            child: Icon(Icons.my_location),
            backgroundColor: Colors.blue,
          ),
        ],
      ) : null,
    );
  }

  // Update speed tracking with max and average calculations
  void _updateSpeedTracking(double newSpeed) {
    setState(() {
      _currentSpeed = newSpeed;
      
      // Update max speed
      if (newSpeed > _maxSpeed) {
        _maxSpeed = newSpeed;
      }
      
      // Calculate average speed (simple moving average)
      if (_elapsedTime.inSeconds > 0) {
        _averageSpeed = _totalDistance / (_elapsedTime.inHours + 0.001);
      }
    });
  }
  
  // End tour functionality
  void _endTour() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turu Bitir'),
        content: const Text('Turu bitirmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close map screen
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Bitir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  // Settings dialog
  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Harita Ayarları'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom Controls
                SwitchListTile(
                  title: const Text('Zoom Butonları'),
                  subtitle: const Text('Haritada +/- zoom butonlarını göster'),
                  value: _zoomControlsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _zoomControlsEnabled = value;
                    });
                  },
                ),
                
                // My Location Button
                SwitchListTile(
                  title: const Text('Konum Butonu'),
                  subtitle: const Text('Mevcut konuma gitme butonunu göster'),
                  value: _myLocationButtonEnabled,
                  onChanged: (value) {
                    setState(() {
                      _myLocationButtonEnabled = value;
                    });
                  },
                ),
                
                // Compass
                SwitchListTile(
                  title: const Text('Pusula'),
                  subtitle: const Text('Harita üzerinde puslayı göster'),
                  value: _compassEnabled,
                  onChanged: (value) {
                    setState(() {
                      _compassEnabled = value;
                    });
                  },
                ),
                
                // Traffic
                SwitchListTile(
                  title: const Text('Trafik Bilgisi'),
                  subtitle: const Text('Gerçek zamanlı trafik durumunu göster'),
                  value: _trafficEnabled,
                  onChanged: (value) {
                    setState(() {
                      _trafficEnabled = value;
                    });
                  },
                ),
                
                // Buildings
                SwitchListTile(
                  title: const Text('3D Binalar'),
                  subtitle: const Text('Haritada 3D binaları göster'),
                  value: _buildingsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _buildingsEnabled = value;
                    });
                  },
                ),
                
                const Divider(),
                
                // Map Type
                ListTile(
                  title: const Text('Harita Tipi'),
                  subtitle: Text(_getMapTypeName(_currentMapType)),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    _showMapTypeDialog();
                  },
                ),
                
                // Zoom Level
                ListTile(
                  title: const Text('Zoom Seviyesi'),
                  subtitle: Text('${_currentZoom.toStringAsFixed(1)}x'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: _currentZoom > 3 ? () {
                          setState(() {
                            _currentZoom = (_currentZoom - 1).clamp(3.0, 21.0);
                          });
                          _updateMapZoom();
                        } : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _currentZoom < 21 ? () {
                          setState(() {
                            _currentZoom = (_currentZoom + 1).clamp(3.0, 21.0);
                          });
                          _updateMapZoom();
                        } : null,
                      ),
                    ],
                  ),
                ),
                
                const Divider(),
                
                // Debug Mode
                SwitchListTile(
                  title: const Text('Debug Modu'),
                  subtitle: const Text('Geliştirici bilgilerini göster'),
                  value: _enableMapDebug,
                  onChanged: (value) {
                    setState(() {
                      _enableMapDebug = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  // Build quick stat widget for bottom panel
  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Build detail stat widget for expanded bottom panel
  Widget _buildDetailStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for settings
  String _getMapTypeName(MapType type) {
    switch (type) {
      case MapType.normal:
        return 'Normal';
      case MapType.satellite:
        return 'Uydu';
      case MapType.terrain:
        return 'Arazi';
      case MapType.hybrid:
        return 'Hibrit';
      default:
        return 'Normal';
    }
  }

  void _showMapTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Harita Tipi Seçin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMapTypeOption(MapType.normal, 'Normal', 'Standart harita görünümü'),
            _buildMapTypeOption(MapType.satellite, 'Uydu', 'Uydu görüntüleri'),
            _buildMapTypeOption(MapType.terrain, 'Arazi', 'Topografik harita'),
            _buildMapTypeOption(MapType.hybrid, 'Hibrit', 'Uydu + yol isimleri'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }

  Widget _buildMapTypeOption(MapType type, String title, String subtitle) {
    return RadioListTile<MapType>(
      title: Text(title),
      subtitle: Text(subtitle),
      value: type,
      groupValue: _currentMapType,
      onChanged: (MapType? value) {
        if (value != null) {
          setState(() {
            _currentMapType = value;
          });
          Navigator.pop(context);
        }
      },
    );
  }

  void _updateMapZoom() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.zoomTo(_currentZoom),
      );
    }
  }

}
