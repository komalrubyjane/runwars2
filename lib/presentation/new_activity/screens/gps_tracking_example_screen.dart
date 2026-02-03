import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../common/location/models/gps_tracking_model.dart';
import '../../common/location/view_model/location_view_model.dart';
import '../../common/location/view_model/run_control_view_model.dart';
import '../../common/location/view_model/state/location_state.dart';
import '../../common/location/view_model/state/run_control_state.dart';
import '../../common/location/widgets/gps_tracking_stats.dart';
import '../../common/location/widgets/map_visualization_utils.dart';
import '../../common/location/widgets/run_control_button.dart';
import '../../common/location/widgets/location_map.dart';

/// Example screen demonstrating full GPS tracking capabilities
class GPSTrackingExampleScreen extends HookConsumerWidget {
  const GPSTrackingExampleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runState = ref.watch(runControlViewModelProvider);
    final locationState = ref.watch(locationViewModelProvider);
    final locationNotifier = ref.read(locationViewModelProvider.notifier);
    final runNotifier = ref.read(runControlViewModelProvider.notifier);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('GPS Tracking'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Map', icon: Icon(Icons.map)),
              Tab(text: 'Stats', icon: Icon(Icons.show_chart)),
              Tab(text: 'Details', icon: Icon(Icons.details)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Map Tab
            _buildMapTab(
              context,
              ref,
              locationNotifier,
              locationState,
              runState,
            ),
            // Statistics Tab
            _buildStatsTab(runState),
            // Details Tab
            _buildDetailsTab(locationNotifier, runState),
          ],
        ),
        floatingActionButton: RunControlButton(
          onRunStarted: () {
            locationNotifier.startRun();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Run started')),
            );
          },
          onRunStopped: () {
            final stats = locationNotifier.stopRun();
            runNotifier.stopRun(stats);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Run completed: ${(stats.totalDistance / 1000).toStringAsFixed(2)}km',
                ),
              ),
            );
          },
          onRunPaused: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Run paused')),
            );
          },
          onRunResumed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Run resumed')),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMapTab(
    BuildContext context,
    WidgetRef ref,
    LocationViewModel locationNotifier,
    LocationState locationState,
    RunControlState runState,
  ) {
    final loops = locationNotifier.getDetectedLoops();
    final territory = locationNotifier.getTerritory();
    final track = locationNotifier.getGPSTrack();

    // Convert GPS points to LatLng for map
    final trackPoints = track.map((p) => p.position).toList();

    // Build circles for loops
    final circles = MapVisualizationUtils.createLoopCircles(loops);

    // Build territory polygons
    final polygons = territory != null
        ? MapVisualizationUtils.createTerritoryPolygon(territory)
        : <Polygon>{};

    // Build loop markers
    final loopMarkers = MapVisualizationUtils.createLoopMarkers(loops);

    // Build polylines for territory boundary
    final boundaryPolylines = territory != null
        ? MapVisualizationUtils.createTerritoryBoundary(territory)
        : <Polyline>{};

    // Build speed gradient track
    final speedPolylines = MapVisualizationUtils.createSpeedGradientTrack(track);

    return Stack(
      children: [
        // Google Map
        LocationMap(
          points: trackPoints,
          markers: loopMarkers.toList(),
          mapController: null,
          circles: circles,
          polygons: polygons,
          customPolylines: <Polyline>{
            ...boundaryPolylines,
            ...speedPolylines,
          },
        ),
        // Info card
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Run Status: ${_getRunStatus(runState)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Points: ${track.length}'),
                Text('Loops: ${loops.length}'),
                if (territory != null)
                  Text(
                    'Area: ${(territory.areaSquareMeters / 10000).toStringAsFixed(2)} ha',
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsTab(RunControlState runState) {
    final statistics = runState.finalStatistics;

    if (statistics == null) {
      return const Center(
        child: Text('Complete a run to see statistics'),
      );
    }

    return GPSTrackingStats(statistics: statistics);
  }

  Widget _buildDetailsTab(
    LocationViewModel locationNotifier,
    RunControlState runState,
  ) {
    final loops = locationNotifier.getDetectedLoops();
    final territory = locationNotifier.getTerritory();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Loops Section
          if (loops.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detected Loops',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: loops.length,
                  itemBuilder: (context, index) {
                    final loop = loops[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Loop ${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              'Radius',
                              '${loop.radiusMeters.toStringAsFixed(0)}m',
                            ),
                            _buildDetailRow(
                              'Points',
                              loop.pointsInLoop.length.toString(),
                            ),
                            _buildDetailRow(
                              'Center',
                              '${loop.loopCenter.latitude.toStringAsFixed(4)}, ${loop.loopCenter.longitude.toStringAsFixed(4)}',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          // Territory Section
          if (territory != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Territory Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          'Area',
                          '${(territory.areaSquareMeters / 10000).toStringAsFixed(2)} hectares',
                        ),
                        _buildDetailRow(
                          'Area (sq meters)',
                          territory.areaSquareMeters.toStringAsFixed(0),
                        ),
                        _buildDetailRow(
                          'Boundary Points',
                          territory.boundaryPoints.length.toString(),
                        ),
                        _buildDetailRow(
                          'Total Points',
                          territory.allPointsInTerritory.length.toString(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          if (loops.isEmpty && territory == null)
            const Center(
              child: Text('Start a run to see loop and territory details'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getRunStatus(RunControlState state) {
    if (state.hasRunEnded) return 'Finished';
    if (state.isRunning) return 'Active';
    if (state.isPaused) return 'Paused';
    return 'Not Started';
  }
}
