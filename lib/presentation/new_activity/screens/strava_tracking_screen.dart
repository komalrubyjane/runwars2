import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../common/location/models/gps_tracking_model.dart';
import '../../common/location/view_model/location_view_model.dart';
import '../../common/location/view_model/state/location_state.dart';
import '../../common/location/view_model/run_control_view_model.dart';
import '../../common/location/view_model/state/run_control_state.dart';
import '../../common/location/widgets/animated_runner_overlay.dart';
import '../../common/location/widgets/run_control_button.dart';
import '../../common/location/utils/runner_marker_icon.dart';
import '../../common/location/widgets/tracking_map_with_grid.dart';
import '../../common/metrics/widgets/metrics.dart';

final _runnerIconProvider = FutureProvider<BitmapDescriptor>((ref) => getRunnerMarkerIcon());

final _userProfileProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  if (userId.isEmpty) return null;
  return SupabaseService().getUserProfile(userId);
});

/// Strava-like activity tracking screen with live metrics
class StravaTrackingScreen extends HookConsumerWidget {
  const StravaTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runState = ref.watch(runControlViewModelProvider);
    final locationState = ref.watch(locationViewModelProvider);
    final locationNotifier = ref.read(locationViewModelProvider.notifier);
    final runNotifier = ref.read(runControlViewModelProvider.notifier);

    useEffect(() {
      _requestLocationPermission(context, locationNotifier);
      locationNotifier.startGettingLocation();
      return () {};
    }, []);

    // Tick every 300ms when run active so timer, distance and speed update in real time
    final tick = useState(0);
    useEffect(() {
      if (!runState.isRunning && !runState.isPaused) return null;
      final t = Timer.periodic(const Duration(milliseconds: 300), (_) {
        tick.value++;
      });
      return t.cancel;
    }, [runState.isRunning, runState.isPaused]);

    // Use watched location state so polyline and metrics rebuild on every GPS update
    List<LatLng> points = locationState.savedPositions
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    // Extend polyline to current position in real time when run is active
    if ((runState.isRunning || runState.isPaused) &&
        locationState.currentPosition != null &&
        points.isNotEmpty) {
      final curr = locationState.currentPosition!;
      final last = points.last;
      if (last.latitude != curr.latitude || last.longitude != curr.longitude) {
        points = [...points, LatLng(curr.latitude, curr.longitude)];
      }
    }

    // Markers: start (green), end when finished (red), runner/current (orange/blue)
    final isRunning = runState.isRunning;
    final markers = <Marker>{};
    // Start point of trajectory
    if (points.isNotEmpty) {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: points.first,
          infoWindow: const InfoWindow(title: 'Start', snippet: 'Starting point'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
      // End point when run has ended (last recorded point)
      if (runState.hasRunEnded && points.length >= 2) {
        markers.add(
          Marker(
            markerId: const MarkerId('end'),
            position: points.last,
            infoWindow: const InfoWindow(title: 'End', snippet: 'Finish point'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      }
    }
    // Current position / runner — use stick-figure icon when running, else default
    final runnerIconAsync = ref.watch(_runnerIconProvider);
    final runnerIcon = runnerIconAsync.valueOrNull;
    if (locationState.currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('runner'),
          position: LatLng(
            locationState.currentPosition!.latitude,
            locationState.currentPosition!.longitude,
          ),
          infoWindow: InfoWindow(
            title: isRunning ? 'Running' : 'Your Location',
            snippet: isRunning ? 'You are here' : 'You are here',
          ),
          icon: (isRunning && runnerIcon != null)
              ? runnerIcon
              : BitmapDescriptor.defaultMarkerWithHue(
                  isRunning ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueBlue,
                ),
        ),
      );
    }

    // Closed-loop polygons from detected loops
    final detectedLoops = locationNotifier.getDetectedLoops();
    final closedLoopPolygons = detectedLoops
        .map((l) => l.pointsInLoop.map((p) => p.position).toList())
        .toList();

    final userId = SupabaseService().currentUser?.id;
    final profileAsync = ref.watch(_userProfileProvider(userId ?? ''));

    final userName = profileAsync.valueOrNull?['full_name'] as String? ??
        SupabaseService().currentUser?.email?.split('@').first ?? 'Runner';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Record Activity', style: TextStyle(fontSize: 18)),
            Text(userName, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.normal)),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Map View with animated runner overlay when running
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Stack(
                children: [
                  TrackingMapWithGrid(
                    points: points,
                    markers: markers,
                    closedLoopPolygons: closedLoopPolygons,
                  ),
                  if (isRunning || runState.isPaused)
                    Positioned(
                      left: 16,
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const AnimatedRunnerOverlay(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Live Metrics Card
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(runState),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _getStatusIcon(runState),
                        const SizedBox(width: 12),
                        Text(
                          _getStatusText(runState),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Primary Metrics - 2x2 grid
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('DISTANCE', '${(locationState.savedPositions.isNotEmpty ? _calculateDistance(locationState.savedPositions) / 1000 : 0).toStringAsFixed(2)}', 'km')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMetricCard('TIME', _formatTime(runNotifier.getElapsedSeconds()), '')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('STEPS', '${locationState.stepCount}', '')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMetricCard('SPEED', _formatSpeed(locationState, runNotifier.getElapsedSeconds()), 'km/h')),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // GPS status (compact)
                  if (locationState.currentPosition != null)
                    Row(
                      children: [
                        Icon(Icons.gps_fixed, size: 16, color: Colors.green[700]),
                        const SizedBox(width: 6),
                        Text('GPS: ${locationState.currentPosition!.accuracy.toStringAsFixed(0)}m', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  const SizedBox(height: 12),

                  const Metrics(),
                  const SizedBox(height: 20),

                  // Loop & Territory Info (if available)
                  if (runState.isRunning || runState.isPaused)
                    _buildActivityInfo(locationNotifier, runState),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: RunControlButton(
        onRunStarted: () {
          locationNotifier.startRun();
          runNotifier.startRun();
        },
        onRunStopped: () {
          final stats = locationNotifier.stopRun();
          runNotifier.stopRun(stats);
          _claimTilesForCompletedLoops(ref, locationNotifier);
          _showActivitySummaryDialog(context, ref, stats);
        },
        onRunPaused: () {
          locationNotifier.stopLocationStream();
        },
        onRunResumed: () {
          locationNotifier.resumeLocationStream();
        },
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          textBaseline: TextBaseline.alphabetic,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildActivityInfo(
    LocationViewModel locationNotifier,
    RunControlState runState,
  ) {
    final loops = locationNotifier.getDetectedLoops();
    final territory = locationNotifier.getTerritory();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 12),
        const Text(
          'Activity Highlights',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        if (loops.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.loop, color: Colors.blue),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${loops.length} Loop${loops.length > 1 ? 's' : ''} Detected',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Max radius: ${loops.map((l) => l.radiusMeters).reduce((a, b) => a > b ? a : b).toStringAsFixed(0)}m',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (territory != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.map, color: Colors.green),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Area Covered',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(territory.areaSquareMeters / 10000).toStringAsFixed(2)} ha',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Color _getStatusColor(RunControlState state) {
    if (state.isRunning) return Colors.green;
    if (state.isPaused) return Colors.orange;
    return Colors.grey;
  }

  Widget _getStatusIcon(RunControlState state) {
    if (state.isRunning) {
      return const Icon(Icons.fiber_manual_record, color: Colors.white);
    }
    return const Icon(Icons.pause_circle, color: Colors.white);
  }

  String _getStatusText(RunControlState state) {
    if (state.isRunning) return 'RECORDING';
    if (state.isPaused) return 'PAUSED';
    if (state.hasRunEnded) return 'COMPLETED';
    return 'READY';
  }

  /// Haversine distance in meters along the path (for real-time distance/speed).
  double _calculateDistance(List locationData) {
    if (locationData.length < 2) return 0;
    const R = 6371000.0; // Earth radius in meters
    double total = 0;
    for (int i = 1; i < locationData.length; i++) {
      final lat1 = locationData[i - 1].latitude * math.pi / 180;
      final lat2 = locationData[i].latitude * math.pi / 180;
      final dLat = (locationData[i].latitude - locationData[i - 1].latitude) * math.pi / 180;
      final dLon = (locationData[i].longitude - locationData[i - 1].longitude) * math.pi / 180;
      final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      total += R * c;
    }
    return total;
  }

  String _formatSpeed(LocationState locState, int elapsedSeconds) {
    if (locState.savedPositions.isEmpty || elapsedSeconds <= 0) return '0.0';
    final distKm = _calculateDistance(locState.savedPositions) / 1000;
    return (distKm / (elapsedSeconds / 3600)).toStringAsFixed(1);
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showActivitySummaryDialog(
    BuildContext context,
    WidgetRef ref,
    RunStatistics stats,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activity Complete! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogStatRow('Distance', '${(stats.totalDistance / 1000).toStringAsFixed(2)} km'),
            _buildDialogStatRow('Time', _formatDuration(stats.totalTime)),
            _buildDialogStatRow('Avg Speed', '${(stats.averageSpeed * 3.6).toStringAsFixed(2)} km/h'),
            _buildDialogStatRow('Max Speed', '${(stats.maxSpeed * 3.6).toStringAsFixed(2)} km/h'),
            if (stats.totalAltitudeGain > 0)
              _buildDialogStatRow('Elevation Gain', '${stats.totalAltitudeGain.toStringAsFixed(0)} m'),
            if (stats.detectedLoops.isNotEmpty)
              _buildDialogStatRow('Loops', stats.detectedLoops.length.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('View Details'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
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
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes}m ${seconds}s';
  }

  void _claimTilesForCompletedLoops(WidgetRef ref, LocationViewModel locationNotifier) {
    final user = SupabaseService().currentUser;
    if (user == null) return;
    final loops = locationNotifier.getDetectedLoops();
    if (loops.isEmpty) return;
    final tileService = ref.read(territoryTileServiceProvider);
    final userName = user.userMetadata?['full_name'] as String? ??
        user.email?.split('@').first ??
        'Runner';
    for (final loop in loops) {
      final polygon = loop.pointsInLoop.map((p) => p.position).toList();
      if (polygon.length >= 3) {
        tileService.claimTilesInPolygon(polygon, user.id, ownerName: userName);
      }
    }
  }

  Future<void> _requestLocationPermission(
    BuildContext context,
    LocationViewModel locationNotifier,
  ) async {
    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        // Permissions denied
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '❌ Location permission denied. Please enable it in settings to track your location.',
              ),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (permission == LocationPermission.deniedForever) {
        // Permissions denied forever, open settings
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('📍 Location Permission Required'),
              content: const Text(
                'This app needs access to your real GPS location to track your runs accurately. Please enable "Location" permission in app settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Geolocator.openLocationSettings();
                    Navigator.pop(context);
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Permission granted
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Location access granted! Your GPS is now being tracked.'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Get initial position with best accuracy
        try {
          await Geolocator.getCurrentPosition(
            forceAndroidLocationManager: false,
          );
        } catch (e) {
          print('Error getting initial position: $e');
        }
      }
    } else if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      // Permission already granted
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Using your real GPS location for tracking'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
