import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:aracfilo/variables/variables.dart';

// Map Control Buttons Widget
class MapControlButtons extends StatelessWidget {
  final GoogleMapController? mapController;
  final Position? currentPosition;
  final bool isBottomSheetExpanded;
  final double currentZoom;
  final VoidCallback onLocationPressed;
  final ValueChanged<double> onZoomChanged;
  final bool zoomControlsEnabled;
  final bool compassEnabled;
  final bool myLocationButtonEnabled;

  const MapControlButtons({
    super.key,
    required this.mapController,
    required this.currentPosition,
    required this.isBottomSheetExpanded,
    required this.currentZoom,
    required this.onLocationPressed,
    required this.onZoomChanged,
    required this.zoomControlsEnabled,
    required this.compassEnabled,
    required this.myLocationButtonEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Compass Button - moves with bottom bar
        if (compassEnabled)
          Positioned(
            right: 16,
            bottom: isBottomSheetExpanded ? 380 : 280,
            child: FloatingActionButton(
              mini: true,
              heroTag: "compass",
              backgroundColor: Colors.black.withValues(alpha: 0.7),
              onPressed: _onCompassPressed,
              child: Icon(
                Icons.navigation,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

        // Location Button - 20px above expanded bottom bar
        if (myLocationButtonEnabled)
          Positioned(
            right: 16,
            bottom: isBottomSheetExpanded ? 220 : 120,
            child: FloatingActionButton(
              mini: true,
              heroTag: "my_location",
              backgroundColor: Colors.black.withValues(alpha: 0.7),
              onPressed: onLocationPressed,
              child: Icon(
                Icons.my_location,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

        // Zoom Controls - 30px above location button
        if (zoomControlsEnabled)
          Positioned(
            right: 16,
            bottom: isBottomSheetExpanded ? 280 : 180,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  heroTag: "zoom_in",
                  backgroundColor: Colors.black.withValues(alpha: 0.7),
                  onPressed: _onZoomIn,
                  child: Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  heroTag: "zoom_out",
                  backgroundColor: Colors.black.withValues(alpha: 0.7),
                  onPressed: _onZoomOut,
                  child: Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _onCompassPressed() {
    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentPosition != null 
              ? LatLng(currentPosition!.latitude, currentPosition!.longitude)
              : AppVariables.defaultMapCenter,
            zoom: currentZoom,
            bearing: 0.0, // North up
            tilt: 0.0,
          ),
        ),
      );
    }
  }

  void _onZoomIn() {
    if (mapController != null) {
      final newZoom = (currentZoom + 1).clamp(AppVariables.minMapZoom, AppVariables.maxMapZoom);
      onZoomChanged(newZoom);
      mapController!.animateCamera(
        CameraUpdate.zoomTo(newZoom),
      );
    }
  }

  void _onZoomOut() {
    if (mapController != null) {
      final newZoom = (currentZoom - 1).clamp(AppVariables.minMapZoom, AppVariables.maxMapZoom);
      onZoomChanged(newZoom);
      mapController!.animateCamera(
        CameraUpdate.zoomTo(newZoom),
      );
    }
  }
}

class MapSettingsDialog extends StatefulWidget {
  final bool zoomControlsEnabled;
  final bool myLocationButtonEnabled;
  final bool compassEnabled;
  final bool trafficEnabled;
  final bool buildingsEnabled;
  final double currentZoom;
  final MapType currentMapType;
  final bool enableMapDebug;
  final ValueChanged<Map<String, dynamic>> onSettingsChanged;

  const MapSettingsDialog({
    super.key,
    required this.zoomControlsEnabled,
    required this.myLocationButtonEnabled,
    required this.compassEnabled,
    required this.trafficEnabled,
    required this.buildingsEnabled,
    required this.currentZoom,
    required this.currentMapType,
    required this.enableMapDebug,
    required this.onSettingsChanged,
  });

  @override
  State<MapSettingsDialog> createState() => _MapSettingsDialogState();
}

class _MapSettingsDialogState extends State<MapSettingsDialog> {
  late bool _zoomControlsEnabled;
  late bool _myLocationButtonEnabled;
  late bool _compassEnabled;
  late bool _trafficEnabled;
  late bool _buildingsEnabled;
  late double _currentZoom;
  late MapType _currentMapType;
  late bool _enableMapDebug;

  @override
  void initState() {
    super.initState();
    _zoomControlsEnabled = widget.zoomControlsEnabled;
    _myLocationButtonEnabled = widget.myLocationButtonEnabled;
    _compassEnabled = widget.compassEnabled;
    _trafficEnabled = widget.trafficEnabled;
    _buildingsEnabled = widget.buildingsEnabled;
    _currentZoom = widget.currentZoom;
    _currentMapType = widget.currentMapType;
    _enableMapDebug = widget.enableMapDebug;
  }

  void _notifySettingsChanged() {
    widget.onSettingsChanged({
      'zoomControlsEnabled': _zoomControlsEnabled,
      'myLocationButtonEnabled': _myLocationButtonEnabled,
      'compassEnabled': _compassEnabled,
      'trafficEnabled': _trafficEnabled,
      'buildingsEnabled': _buildingsEnabled,
      'currentZoom': _currentZoom,
      'currentMapType': _currentMapType,
      'enableMapDebug': _enableMapDebug,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppVariables.dialogBorderRadius),
      ),
      child: Container(
        padding: AppVariables.dialogPadding,
        width: MediaQuery.of(context).size.width * AppVariables.dialogWidthRatio,
        constraints: const BoxConstraints(
          maxWidth: AppVariables.dialogMaxWidth,
          maxHeight: 500, // Fixed height to prevent overflow
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    AppVariables.settingsTitle,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Map Type Selection
              const Text(
                AppVariables.mapTypeLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<MapType>(
                value: _currentMapType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: AppVariables.mapTypeDisplayNames.keys.map((mapType) {
                  return DropdownMenuItem(
                    value: mapType,
                    child: Text(AppVariables.getMapTypeDisplayName(mapType)),
                  );
                }).toList(),
                onChanged: (MapType? value) {
                  if (value != null) {
                    setState(() {
                      _currentMapType = value;
                    });
                    _notifySettingsChanged();
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Zoom Level
              const Text(
                AppVariables.zoomLevelLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(AppVariables.minMapZoom.toInt().toString()),
                  Expanded(
                    child: Slider(
                      value: _currentZoom,
                      min: AppVariables.minMapZoom,
                      max: AppVariables.maxMapZoom,
                      divisions: (AppVariables.maxMapZoom - AppVariables.minMapZoom).toInt(),
                      label: _currentZoom.toStringAsFixed(1),
                      onChanged: (double value) {
                        setState(() {
                          _currentZoom = value;
                        });
                        _notifySettingsChanged();
                      },
                    ),
                  ),
                  Text(AppVariables.maxMapZoom.toInt().toString()),
                ],
              ),
              const SizedBox(height: 16),
              
              // Toggle Options
              const Text(
                AppVariables.mapFeaturesLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              
              _buildToggleOption(
                AppVariables.zoomControlsLabel,
                _zoomControlsEnabled,
                (bool value) {
                  setState(() {
                    _zoomControlsEnabled = value;
                  });
                  _notifySettingsChanged();
                },
              ),
              
              _buildToggleOption(
                AppVariables.locationButtonLabel,
                _myLocationButtonEnabled,
                (bool value) {
                  setState(() {
                    _myLocationButtonEnabled = value;
                  });
                  _notifySettingsChanged();
                },
              ),
              
              _buildToggleOption(
                AppVariables.compassLabel,
                _compassEnabled,
                (bool value) {
                  setState(() {
                    _compassEnabled = value;
                  });
                  _notifySettingsChanged();
                },
              ),
              
              _buildToggleOption(
                AppVariables.trafficLabel,
                _trafficEnabled,
                (bool value) {
                  setState(() {
                    _trafficEnabled = value;
                  });
                  _notifySettingsChanged();
                },
              ),
              
              _buildToggleOption(
                AppVariables.buildingsLabel,
                _buildingsEnabled,
                (bool value) {
                  setState(() {
                    _buildingsEnabled = value;
                  });
                  _notifySettingsChanged();
                },
              ),
              
              _buildToggleOption(
                AppVariables.debugModeLabel,
                _enableMapDebug,
                (bool value) {
                  setState(() {
                    _enableMapDebug = value;
                  });
                  _notifySettingsChanged();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption(String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppVariables.infoColor,
          ),
        ],
      ),
    );
  }
  
  

}