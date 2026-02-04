import '../../models/gps_tracking_model.dart';

/// State for run control and management
class RunControlState {
  /// Whether the run is currently active
  final bool isRunning;

  /// Whether the run is paused
  final bool isPaused;

  /// When the run started
  final DateTime? runStartTime;

  /// When the run ended
  final DateTime? runEndTime;

  /// Whether the run has ended
  final bool hasRunEnded;

  /// Final statistics from the run (cleared when starting a new run)
  final RunStatistics? finalStatistics;

  /// Last completed run statistics (kept when starting new run so "Last run" stays visible)
  final RunStatistics? lastCompletedRunStatistics;

  /// Whether the run has been started at all
  bool get hasRunStarted => runStartTime != null;

  const RunControlState({
    required this.isRunning,
    required this.isPaused,
    required this.runStartTime,
    required this.runEndTime,
    required this.hasRunEnded,
    required this.finalStatistics,
    this.lastCompletedRunStatistics,
  });

  factory RunControlState.initial() {
    return const RunControlState(
      isRunning: false,
      isPaused: false,
      runStartTime: null,
      runEndTime: null,
      hasRunEnded: false,
      finalStatistics: null,
      lastCompletedRunStatistics: null,
    );
  }

  RunControlState copyWith({
    bool? isRunning,
    bool? isPaused,
    DateTime? runStartTime,
    DateTime? runEndTime,
    bool? hasRunEnded,
    RunStatistics? finalStatistics,
    RunStatistics? lastCompletedRunStatistics,
  }) {
    return RunControlState(
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      runStartTime: runStartTime ?? this.runStartTime,
      runEndTime: runEndTime ?? this.runEndTime,
      hasRunEnded: hasRunEnded ?? this.hasRunEnded,
      finalStatistics: finalStatistics ?? this.finalStatistics,
      lastCompletedRunStatistics: lastCompletedRunStatistics ?? this.lastCompletedRunStatistics,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunControlState &&
          runtimeType == other.runtimeType &&
          isRunning == other.isRunning &&
          isPaused == other.isPaused &&
          runStartTime == other.runStartTime &&
          runEndTime == other.runEndTime &&
          hasRunEnded == other.hasRunEnded &&
          finalStatistics == other.finalStatistics &&
          lastCompletedRunStatistics == other.lastCompletedRunStatistics;

  @override
  int get hashCode =>
      isRunning.hashCode ^
      isPaused.hashCode ^
      runStartTime.hashCode ^
      runEndTime.hashCode ^
      hasRunEnded.hashCode ^
      finalStatistics.hashCode ^
      lastCompletedRunStatistics.hashCode;
}
