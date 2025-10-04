import 'package:flutter/material.dart';
import 'package:aracfilo/variables/variables.dart';

class MapBottomBar extends StatefulWidget {
  final String driverName;
  final String vehiclePlate;
  final double currentSpeed;
  final double maxSpeed;
  final double averageSpeed;
  final double totalDistance;
  final Duration elapsedTime;
  final VoidCallback onToggle;
  final bool isExpanded;
  final Animation<double> animation;

  const MapBottomBar({
    super.key,
    required this.driverName,
    required this.vehiclePlate,
    required this.currentSpeed,
    required this.maxSpeed,
    required this.averageSpeed,
    required this.totalDistance,
    required this.elapsedTime,
    required this.onToggle,
    required this.isExpanded,
    required this.animation,
  });

  @override
  State<MapBottomBar> createState() => _MapBottomBarState();
}

class _MapBottomBarState extends State<MapBottomBar> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedBuilder(
          animation: widget.animation,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
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
                  // Handle indicator
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                
                  // Simple horizontal stats like in image
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSimpleStat(
                        'Hız',
                        '${widget.currentSpeed.toStringAsFixed(1)} km/h',
                        Icons.speed,
                        Colors.blue,
                      ),
                      _buildSimpleStat(
                        'Mesafe',
                        '${widget.totalDistance.toStringAsFixed(2)} km',
                        Icons.straighten,
                        Colors.green,
                      ),
                    ],
                  ),
                  
                  // Expanded content with animation
                  AnimatedContainer(
                    duration: AppVariables.bottomSheetAnimationDuration,
                    curve: AppVariables.bottomSheetAnimationCurve,
                    height: widget.isExpanded ? null : 0,
                    child: widget.isExpanded ? Column(
                      children: [
                        const SizedBox(height: 12),
                        
                        // Detailed stats - 3 columns like in image
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCompactStat(
                              'Süre',
                              AppVariables.formatDuration(widget.elapsedTime),
                              Icons.timer,
                            ),
                            _buildCompactStat(
                              'Ort. Hız',
                              '${widget.averageSpeed.toStringAsFixed(1)} km/h',
                              Icons.trending_up,
                            ),
                            _buildCompactStat(
                              'Maks. Hız',
                              '${widget.maxSpeed.toStringAsFixed(1)} km/h',
                              Icons.speed,
                            ),
                          ],
                        ),
                      ],
                    ) : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
