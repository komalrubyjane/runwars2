import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/gps_tracking_model.dart';
import '../services/territory_capture_service.dart';
import '../view_model/location_view_model.dart';

/// Widget that displays GPS tracking statistics and analytics
class GPSTrackingStats extends HookConsumerWidget {
  final RunStatistics? statistics;

  const GPSTrackingStats({
    super.key,
    this.statistics,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = statistics;

    if (stats == null) {
      return const Center(
        child: Text('No tracking data available'),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Stats
            _buildStatSection(
              title: 'Basic Statistics',
              children: [
                _buildStatRow(
                  'Total Distance',
                  '${(stats.totalDistance / 1000).toStringAsFixed(2)} km',
                  Icons.location_on,
                ),
                _buildStatRow(
                  'Total Time',
                  _formatDuration(stats.totalTime),
                  Icons.timer,
                ),
                _buildStatRow(
                  'Average Speed',
                  '${(stats.averageSpeed * 3.6).toStringAsFixed(2)} km/h',
                  Icons.speed,
                ),
                _buildStatRow(
                  'Max Speed',
                  '${(stats.maxSpeed * 3.6).toStringAsFixed(2)} km/h',
                  Icons.trending_up,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Altitude Stats
            if (stats.totalAltitudeGain > 0)
              _buildStatSection(
                title: 'Altitude Statistics',
                children: [
                  _buildStatRow(
                    'Total Altitude Gain',
                    '${stats.totalAltitudeGain.toStringAsFixed(0)} m',
                    Icons.terrain,
                  ),
                ],
              ),
            const SizedBox(height: 16),
            // GPS Points
            _buildStatSection(
              title: 'GPS Data',
              children: [
                _buildStatRow(
                  'GPS Points Recorded',
                  stats.pointCount.toString(),
                  Icons.pin_drop,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Loop Detection
            if (stats.detectedLoops.isNotEmpty)
              _buildStatSection(
                title: 'Loop Detection',
                children: [
                  _buildStatRow(
                    'Loops Detected',
                    stats.detectedLoops.length.toString(),
                    Icons.loop,
                  ),
                  const SizedBox(height: 8),
                  ...stats.detectedLoops.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text(
                        'Loop ${entry.key + 1}: Radius ${(entry.value.radiusMeters).toStringAsFixed(0)}m, Points: ${entry.value.pointsInLoop.length}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            // Territory Capture
            if (stats.territory != null)
              _buildStatSection(
                title: 'Territory Coverage',
                children: [
                  _buildStatRow(
                    'Area Covered',
                    '${(stats.territory!.areaSquareMeters / 10000).toStringAsFixed(2)} hectares',
                    Icons.map,
                  ),
                  _buildStatRow(
                    'Coverage Density',
                    '${TerritoryCaptureService.calculateCoverageDensity(stats.territory!).toStringAsFixed(2)} points/km²',
                    Icons.grid_3x3,
                  ),
                  _buildStatRow(
                    'Boundary Points',
                    stats.territory!.boundaryPoints.length.toString(),
                    Icons.polyline,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}h';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
