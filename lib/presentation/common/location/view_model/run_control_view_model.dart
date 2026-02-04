import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/gps_tracking_model.dart';
import 'state/run_control_state.dart';

final runControlViewModelProvider =
    StateNotifierProvider<RunControlViewModel, RunControlState>(
  (ref) => RunControlViewModel(),
);

/// View model for managing run start/stop controls and run state
class RunControlViewModel extends StateNotifier<RunControlState> {
  RunControlViewModel() : super(RunControlState.initial());

  final _stopwatch = Stopwatch();

  /// Starts a new run
  void startRun() {
    _stopwatch.reset();
    _stopwatch.start();
    state = state.copyWith(
      isRunning: true,
      isPaused: false,
      runStartTime: DateTime.now(),
      runEndTime: null,
      hasRunEnded: false,
    );
  }

  /// Pauses the current run
  void pauseRun() {
    if (state.isRunning) {
      _stopwatch.stop();
      state = state.copyWith(isRunning: false, isPaused: true);
    }
  }

  /// Resumes a paused run
  void resumeRun() {
    if (state.isPaused && !state.hasRunEnded) {
      _stopwatch.start();
      state = state.copyWith(isRunning: true, isPaused: false);
    }
  }

  /// Stops the current run and finalizes it
  void stopRun(RunStatistics statistics) {
    _stopwatch.stop();
    state = state.copyWith(
      isRunning: false,
      isPaused: false,
      runEndTime: DateTime.now(),
      hasRunEnded: true,
      finalStatistics: statistics,
      lastCompletedRunStatistics: statistics,
    );
  }

  /// Resets the run state so user can start a new run; keeps last run stats for display
  void resetRun() {
    _stopwatch.reset();
    final lastStats = state.finalStatistics ?? state.lastCompletedRunStatistics;
    state = RunControlState.initial().copyWith(
      lastCompletedRunStatistics: lastStats,
    );
  }

  RunStatus getRunStatus() {
    if (!state.hasRunStarted) return RunStatus.notStarted;
    if (state.hasRunEnded) return RunStatus.finished;
    if (state.isRunning) return RunStatus.running;
    if (state.isPaused) return RunStatus.paused;
    return RunStatus.notStarted;
  }

  /// Elapsed time from Stopwatch (excludes paused time)
  int getElapsedSeconds() => _stopwatch.elapsed.inSeconds;
}

/// Enum representing different run statuses
enum RunStatus {
  notStarted,
  running,
  paused,
  finished,
}
