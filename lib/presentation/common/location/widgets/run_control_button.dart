import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/gps_tracking_model.dart';
import '../view_model/location_view_model.dart';
import '../view_model/run_control_view_model.dart';

/// Widget that displays start/stop/pause/resume controls for a run
class RunControlButton extends HookConsumerWidget {
  final VoidCallback? onRunStarted;
  final VoidCallback? onRunStopped;
  final VoidCallback? onRunPaused;
  final VoidCallback? onRunResumed;

  const RunControlButton({
    super.key,
    this.onRunStarted,
    this.onRunStopped,
    this.onRunPaused,
    this.onRunResumed,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runControlState = ref.watch(runControlViewModelProvider);
    final runControlNotifier = ref.read(runControlViewModelProvider.notifier);
    final locationNotifier = ref.read(locationViewModelProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _getStatusColor(runControlState.isRunning, runControlState.isPaused, runControlState.hasRunEnded),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _getStatusText(runControlState.isRunning, runControlState.isPaused, runControlState.hasRunEnded),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Control buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Start / Resume / New Run button (always visible so user can start again after ending)
            FloatingActionButton(
              onPressed: () {
                if (runControlState.hasRunEnded) {
                  // Start a new run: reset state and clear previous track
                  locationNotifier.resetSavedPositions();
                  runControlNotifier.resetRun();
                  runControlNotifier.startRun();
                  locationNotifier.startRun();
                  onRunStarted?.call();
                } else if (!runControlState.hasRunStarted) {
                  runControlNotifier.startRun();
                  locationNotifier.startRun();
                  onRunStarted?.call();
                } else if (runControlState.isPaused) {
                  runControlNotifier.resumeRun();
                  locationNotifier.resumeLocationStream();
                  onRunResumed?.call();
                }
              },
              backgroundColor: Colors.green,
              child: Icon(
                runControlState.hasRunEnded ? Icons.replay : Icons.play_arrow,
              ),
            ),
            const SizedBox(width: 16),
            // Pause button (only show if running)
            if (runControlState.isRunning)
              FloatingActionButton(
                onPressed: () {
                  runControlNotifier.pauseRun();
                  locationNotifier.stopLocationStream();
                  onRunPaused?.call();
                },
                backgroundColor: Colors.orange,
                child: const Icon(Icons.pause),
              ),
            const SizedBox(width: 16),
            // Stop button
            if (runControlState.hasRunStarted && !runControlState.hasRunEnded)
              FloatingActionButton(
                onPressed: () {
                  final statistics = locationNotifier.stopRun();
                  runControlNotifier.stopRun(statistics);
                  onRunStopped?.call();
                },
                backgroundColor: Colors.red,
                child: const Icon(Icons.stop),
              ),
          ],
        ),
        // Last run details below when run has ended
        if (runControlState.hasRunEnded && runControlState.finalStatistics != null) ...[
          const SizedBox(height: 16),
          _LastRunSummary(
            stats: runControlState.finalStatistics!,
            formatDuration: _formatDuration,
          ),
        ],
      ],
    );
  }

  String _getStatusText(bool isRunning, bool isPaused, bool hasEnded) {
    if (hasEnded) return 'Run Finished — Tap to start new run';
    if (isRunning) return 'Run Active';
    if (isPaused) return 'Run Paused';
    return 'Ready to Start';
  }

  Color _getStatusColor(bool isRunning, bool isPaused, bool hasEnded) {
    if (hasEnded) return Colors.grey;
    if (isRunning) return Colors.green;
    if (isPaused) return Colors.orange;
    return Colors.grey;
  }
}

/// Compact summary of the last completed run
class _LastRunSummary extends StatelessWidget {
  final RunStatistics stats;
  final String Function(Duration) formatDuration;

  const _LastRunSummary({
    required this.stats,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Last run',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(stats.totalDistance / 1000).toStringAsFixed(2)} km',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                formatDuration(stats.totalTime),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Avg ${(stats.averageSpeed * 3.6).toStringAsFixed(1)} km/h',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
