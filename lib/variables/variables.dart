import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

// =============================================================================
// GLOBAL VARIABLES & CONSTANTS
// =============================================================================

class AppVariables {
  // =============================================================================
  // MAP SETTINGS & CONFIGURATION
  // =============================================================================
  
  // Default Map Settings
  static const double defaultMapZoom = 15.0;
  static const double minMapZoom = 10.0;
  static const double maxMapZoom = 20.0;
  static const MapType defaultMapType = MapType.normal;
  static const LatLng defaultMapCenter = LatLng(41.0082, 28.9784); // İstanbul merkezi
  
  // Map Control Settings
  static const bool defaultZoomControlsEnabled = false;
  static const bool defaultMyLocationButtonEnabled = false;
  static const bool defaultCompassEnabled = true;
  static const bool defaultTrafficEnabled = true;
  static const bool defaultBuildingsEnabled = true;
  
  // Debug Flags - Set to false for production
  static const bool defaultEnableMapDebug = false;
  static const bool defaultEnableLocationDebug = false;
  static const bool defaultEnableRoadDebug = false;
  
  // =============================================================================
  // LOCATION & TRACKING SETTINGS
  // =============================================================================
  
  // Location Accuracy Settings
  static const LocationAccuracy defaultLocationAccuracy = LocationAccuracy.high;
  static const int locationDistanceFilter = 5; // meters
  static const Duration locationTimeLimit = Duration(seconds: 10);
  
  // Speed Tracking
  static const double speedMsToKmhMultiplier = 3.6;
  static const double distanceMToKmDivider = 1000.0;
  
  // =============================================================================
  // UI SETTINGS & DIMENSIONS
  // =============================================================================
  
  // Floating Button Dimensions
  static const double floatingButtonSize = 56.0;
  static const double floatingButtonBorderRadius = 28.0;
  static const double floatingButtonMargin = 16.0;
  
  // Dialog & Panel Settings
  static const double dialogBorderRadius = 16.0;
  static const double dialogMaxWidth = 400.0;
  static const double dialogWidthRatio = 0.85;
  static const EdgeInsets dialogPadding = EdgeInsets.all(20);
  
  // Bottom Sheet Settings
  static const Duration bottomSheetAnimationDuration = Duration(milliseconds: 300);
  static const Curve bottomSheetAnimationCurve = Curves.easeInOut;
  
  // =============================================================================
  // TIMER & TRACKING SETTINGS
  // =============================================================================
  
  // Timer Settings
  static const Duration timerUpdateInterval = Duration(seconds: 1);
  static const Duration snackBarDuration = Duration(seconds: 2);
  static const Duration errorSnackBarDuration = Duration(seconds: 3);
  
  // =============================================================================
  // COLORS & STYLING
  // =============================================================================
  
  // Map Colors
  static const Color mapPolylineColor = Colors.blue;
  static const int mapPolylineWidth = 4;
  static const Color mapMarkerColor = Colors.blue;
  
  // Background Colors
  static const Color floatingButtonBackgroundColor = Colors.black87;
  static const double floatingButtonBackgroundOpacity = 0.7;
  static const Color dialogOverlayColor = Colors.black;
  static const double dialogOverlayOpacity = 0.3;
  
  // Status Colors
  static const Color successColor = Colors.green;
  static const Color errorColor = Colors.red;
  static const Color warningColor = Colors.orange;
  static const Color infoColor = Colors.blue;
  
  // =============================================================================
  // TEXT & LABELS
  // =============================================================================
  
  // Map Type Display Names (Turkish)
  static const Map<MapType, String> mapTypeDisplayNames = {
    MapType.normal: 'Normal',
    MapType.satellite: 'Uydu',
    MapType.terrain: 'Arazi',
    MapType.hybrid: 'Hibrit',
  };
  
  // Settings Labels (Turkish)
  static const String settingsTitle = 'Harita Ayarları';
  static const String mapTypeLabel = 'Harita Tipi';
  static const String zoomLevelLabel = 'Yakınlaştırma Seviyesi';
  static const String mapFeaturesLabel = 'Harita Özellikleri';
  static const String zoomControlsLabel = 'Zoom Kontrolleri';
  static const String locationButtonLabel = 'Konum Butonu';
  static const String compassLabel = 'Pusula';
  static const String trafficLabel = 'Trafik Bilgisi';
  static const String buildingsLabel = 'Binalar';
  static const String debugModeLabel = 'Debug Modu';
  static const String cancelButton = 'İptal';
  static const String saveButton = 'Kaydet';
  
  // Error Messages (Turkish)
  static const String locationServiceDisabledError = 'Lütfen telefon ayarlarından konum servisini açın.';
  static const String locationPermissionDeniedError = 'Konum izni reddedildi.';
  static const String locationPermissionPermanentlyDeniedError = 'Konum izni kalıcı olarak reddedildi. Lütfen ayarlardan açın.';
  static const String locationServiceRequiredError = 'Lütfen konum servisini açın.';
  static const String locationPermissionRequiredError = 'Konum izni gerekli.';
  static const String locationPermissionSettingsError = 'Konum izni gerekli. Lütfen ayarlardan açın.';
  
  // Success Messages (Turkish)
  static const String locationUpdatedSuccess = 'Konum güncellendi';
  
  // Debug Messages (Turkish)
  static const String debugTitle = '🔧 Harita Debug Bilgileri';
  
  // Tour Messages (Turkish)
  static const String endTourTitle = 'Turu Bitir';
  static const String endTourConfirmation = 'Turu bitirmek istediğinizden emin misiniz?';
  static const String endTourButton = 'Bitir';
  
  // =============================================================================
  // API & FIREBASE SETTINGS
  // =============================================================================
  
  // Google Maps API
  static const String googleMapsApiKey = 'AIzaSyCGGUfg_VobsXaFsBTIoSfHIS_hEalK7BE';
  
  // Firebase Collections
  static const String toursCollection = 'tours';
  static const String driversCollection = 'drivers';
  static const String usersCollection = 'users';
  static const String vehiclesCollection = 'vehicles';
  
  // Firebase Fields
  static const String tourStatusField = 'status';
  static const String tourStatusActive = 'active';
  static const String driverIdField = 'driverId';
  static const String emailField = 'email';
  static const String currentLocationField = 'currentLocation';
  static const String currentSpeedField = 'currentSpeed';
  static const String totalDistanceField = 'totalDistance';
  static const String elapsedTimeField = 'elapsedTime';
  static const String routeField = 'route';
  static const String lastLatitudeField = 'lastLatitude';
  static const String lastLongitudeField = 'lastLongitude';
  static const String lastLocationTimeField = 'lastLocationTime';
  static const String assignedVehicleIdField = 'assignedVehicleId';
  static const String vehicleIdField = 'vehicleId';
  static const String plateNumberField = 'plateNumber';
  static const String firstNameField = 'firstName';
  static const String lastNameField = 'lastName';
  static const String nameField = 'name';
  
  // =============================================================================
  // UTILITY METHODS
  // =============================================================================
  
  /// Get display name for map type in Turkish
  static String getMapTypeDisplayName(MapType mapType) {
    return mapTypeDisplayNames[mapType] ?? mapTypeDisplayNames[MapType.normal]!;
  }
  
  /// Format duration to HH:MM:SS string
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }
  
  /// Convert m/s to km/h
  static double convertMsToKmh(double speedMs) {
    return speedMs * speedMsToKmhMultiplier;
  }
  
  /// Convert meters to kilometers
  static double convertMToKm(double distanceM) {
    return distanceM / distanceMToKmDivider;
  }
  
  /// Get default map camera position
  static CameraPosition getDefaultCameraPosition({LatLng? customTarget}) {
    return CameraPosition(
      target: customTarget ?? defaultMapCenter,
      zoom: defaultMapZoom,
      tilt: 0.0,
      bearing: 0.0,
    );
  }
  
  /// Get location settings for tracking
  static LocationSettings getLocationSettings() {
    return LocationSettings(
      accuracy: defaultLocationAccuracy,
      distanceFilter: locationDistanceFilter,
    );
  }
  
  /// Create standard box shadow for floating elements
  static List<BoxShadow> getFloatingElementShadow() {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }
  
  /// Create decoration for floating buttons
  static BoxDecoration getFloatingButtonDecoration() {
    return BoxDecoration(
      color: floatingButtonBackgroundColor.withOpacity(floatingButtonBackgroundOpacity),
      borderRadius: BorderRadius.circular(floatingButtonBorderRadius),
      boxShadow: getFloatingElementShadow(),
    );
  }
  
  /// Create decoration for dialogs
  static BoxDecoration getDialogDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(dialogBorderRadius),
      boxShadow: getFloatingElementShadow(),
    );
  }
}

// =============================================================================
// EXTENSION METHODS
// =============================================================================

extension LatLngExtension on LatLng {
  /// Convert LatLng to Firebase map format
  Map<String, double> toFirebaseMap() {
    return {
      'lat': latitude,
      'lng': longitude,
    };
  }
}

extension DurationExtension on Duration {
  /// Format duration using AppVariables method
  String toFormattedString() {
    return AppVariables.formatDuration(this);
  }
}

extension DoubleExtension on double {
  /// Convert speed from m/s to km/h
  double toKmh() {
    return AppVariables.convertMsToKmh(this);
  }
  
  /// Convert distance from meters to kilometers
  double toKm() {
    return AppVariables.convertMToKm(this);
  }
}
