import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aracfilo/variables/variables.dart';
import 'package:aracfilo/driver/map/map_setting.dart';
import 'package:aracfilo/driver/map/bottom_bar.dart';
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

  // Debug flags for map troubleshooting
  bool _enableMapDebug = AppVariables.defaultEnableMapDebug;
  static const bool _enableLocationDebug = AppVariables.defaultEnableLocationDebug;
  static const bool _enableRoadDebug = AppVariables.defaultEnableRoadDebug;

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
  late AnimationController _bottomSheetController;
  late Animation<double> _bottomSheetAnimation;
  bool _isBottomSheetExpanded = true;
  
  // Map settings
  bool _zoomControlsEnabled = AppVariables.defaultZoomControlsEnabled;
  bool _myLocationButtonEnabled = AppVariables.defaultMyLocationButtonEnabled;
  bool _compassEnabled = AppVariables.defaultCompassEnabled;
  bool _trafficEnabled = AppVariables.defaultTrafficEnabled;
  bool _buildingsEnabled = AppVariables.defaultBuildingsEnabled;
  double _currentZoom = AppVariables.defaultMapZoom;
  MapType _currentMapType = AppVariables.defaultMapType;
  
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
    debugPrint('🔑 Google Maps API Key: ${AppVariables.googleMapsApiKey}');
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
      duration: AppVariables.bottomSheetAnimationDuration,
      vsync: this,
    );
    _bottomSheetAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bottomSheetController,
      curve: AppVariables.bottomSheetAnimationCurve,
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
      _showLocationError(AppVariables.locationServiceDisabledError);
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
        _showLocationError(AppVariables.locationPermissionDeniedError);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (_enableLocationDebug) debugPrint('❌ Konum izni kalıcı olarak reddedildi');
      _showLocationError(AppVariables.locationPermissionPermanentlyDeniedError);
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

      await _firestore.collection('drivers').doc(user.uid).update({
        AppVariables.lastLatitudeField: position.latitude,
        AppVariables.lastLongitudeField: position.longitude,
        AppVariables.lastLocationTimeField: FieldValue.serverTimestamp(),
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
        _showLocationError(AppVariables.locationPermissionSettingsError);
        return;
      }
      
      if (permission == LocationPermission.denied) {
        if (_enableLocationDebug) debugPrint('❌ Konum izni reddedildi');
        _showLocationError(AppVariables.locationPermissionRequiredError);
        return;
      }
      
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (_enableLocationDebug) debugPrint('❌ Konum servisi kapalı');
        _showLocationError(AppVariables.locationServiceRequiredError);
        return;
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: AppVariables.defaultLocationAccuracy,
        timeLimit: AppVariables.locationTimeLimit,
      );
      
      if (_enableLocationDebug) debugPrint('✅ Konum alındı: ${position.latitude}, ${position.longitude}');
      
      setState(() {
        _lastPosition = _currentPosition;
        _currentPosition = position;
        double newSpeed = AppVariables.convertMsToKmh(position.speed);
        _updateSpeedTracking(newSpeed);
      });

      _updateMapPosition(position);
      _updateFirebaseLocation(position);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppVariables.locationUpdatedSuccess),
          backgroundColor: AppVariables.successColor,
          duration: AppVariables.snackBarDuration,
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
        backgroundColor: AppVariables.errorColor,
        duration: AppVariables.errorSnackBarDuration,
      ),
    );
  }

  void _startLocationTracking() {
    final LocationSettings locationSettings = AppVariables.getLocationSettings();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      setState(() {
        _lastPosition = _currentPosition;
        _currentPosition = position;
        double newSpeed = AppVariables.convertMsToKmh(position.speed);
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
          color: AppVariables.mapPolylineColor,
          width: AppVariables.mapPolylineWidth,
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
        _totalDistance += AppVariables.convertMToKm(distance);
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
    _timer = Timer.periodic(AppVariables.timerUpdateInterval, (timer) {
      setState(() {
        _elapsedTime = Duration(seconds: _elapsedTime.inSeconds + 1);
      });
    });
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
            initialCameraPosition: AppVariables.getDefaultCameraPosition(
              customTarget: _lastKnownLocation,
            ),
            myLocationEnabled: false, // We have custom location button
            myLocationButtonEnabled: false, // We have custom location button
            zoomControlsEnabled: false, // We have custom zoom controls
            compassEnabled: false, // We have custom compass button
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
          
        
          // Bottom Floating Panel
          MapBottomBar(
            driverName: _driverName,
            vehiclePlate: _vehiclePlate,
            currentSpeed: _currentSpeed,
            maxSpeed: _maxSpeed,
            averageSpeed: _averageSpeed,
            totalDistance: _totalDistance,
            elapsedTime: _elapsedTime,
            isExpanded: _isBottomSheetExpanded,
            onToggle: () {
              setState(() {
                _isBottomSheetExpanded = !_isBottomSheetExpanded;
              });
            },
            animation: _bottomSheetAnimation,
          ),
          
          // Map Control Buttons from map_setting.dart
          MapControlButtons(
            mapController: _mapController,
            currentPosition: _currentPosition,
            isBottomSheetExpanded: _isBottomSheetExpanded,
            currentZoom: _currentZoom,
            onLocationPressed: _getCurrentPosition,
            onZoomChanged: (newZoom) {
              setState(() {
                _currentZoom = newZoom;
              });
            },
            zoomControlsEnabled: _zoomControlsEnabled,
            compassEnabled: _compassEnabled,
            myLocationButtonEnabled: _myLocationButtonEnabled,
          ),
          
          // Debug buttons (only in debug mode)
          if (_enableMapDebug) ...[
            Positioned(
              left: 16,
              bottom: 150,
              child: Column(
                children: [
                  FloatingActionButton(
                    mini: true,
                    heroTag: "debug_info",
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(AppVariables.debugTitle),
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
                    backgroundColor: Colors.orange.withValues(alpha: 0.8),
                    child: Icon(Icons.info, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
        title: const Text(AppVariables.endTourTitle),
        content: const Text(AppVariables.endTourConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppVariables.cancelButton),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close map screen
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppVariables.errorColor),
            child: const Text(AppVariables.endTourButton, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  // Settings dialog
  Future<void> _showSettings() async {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => MapSettingsDialog(
        zoomControlsEnabled: _zoomControlsEnabled,
        myLocationButtonEnabled: _myLocationButtonEnabled,
        compassEnabled: _compassEnabled,
        trafficEnabled: _trafficEnabled,
        buildingsEnabled: _buildingsEnabled,
        currentZoom: _currentZoom,
        currentMapType: _currentMapType,
        enableMapDebug: _enableMapDebug,
        onSettingsChanged: (Map<String, dynamic> newSettings) {
          setState(() {
            _zoomControlsEnabled = newSettings['zoomControlsEnabled'] ?? _zoomControlsEnabled;
            _myLocationButtonEnabled = newSettings['myLocationButtonEnabled'] ?? _myLocationButtonEnabled;
            _compassEnabled = newSettings['compassEnabled'] ?? _compassEnabled;
            _trafficEnabled = newSettings['trafficEnabled'] ?? _trafficEnabled;
            _buildingsEnabled = newSettings['buildingsEnabled'] ?? _buildingsEnabled;
            _currentZoom = newSettings['currentZoom'] ?? _currentZoom;
            _currentMapType = newSettings['currentMapType'] ?? _currentMapType;
            _enableMapDebug = newSettings['enableMapDebug'] ?? _enableMapDebug;
          });
        },
      ),
    );
  }

}
