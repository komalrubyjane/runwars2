import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:run_flutter_run/core/services/supabase_service.dart';
import 'package:run_flutter_run/data/repositories/activity_repository.dart';

/// Supabase-based activity repository for leaderboard
final supabaseActivityRepositoryProvider = Provider((ref) {
  final supabaseService = SupabaseService();
  return ActivityRepository(supabaseService);
});

/// Provider for Supabase service (for realtime)
final supabaseServiceProvider = Provider((ref) => SupabaseService());

/// State for leaderboard data
class LeaderboardState {
  final List<LeaderboardEntry> entries;
  final bool isLoading;
  final String? error;

  LeaderboardState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    bool? isLoading,
    String? error,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Model for leaderboard entry
class LeaderboardEntry {
  final String userId;
  final String userName;
  final String email;
  final double distance;
  final int steps;

  LeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.email,
    required this.distance,
    required this.steps,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] ?? '',
      userName: json['users']?['full_name'] ?? 'Unknown',
      email: json['users']?['email'] ?? '',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      steps: json['steps'] ?? 0,
    );
  }
}

/// Notifier for leaderboard state with realtime updates
class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  final ActivityRepository activityRepository;
  final SupabaseService supabaseService;
  void Function()? _unsubscribe;

  LeaderboardNotifier(this.activityRepository, this.supabaseService)
      : super(LeaderboardState()) {
    debugPrint('[Supabase Leaderboard] Subscribing to realtime updates');
    fetchLeaderboard();
    _unsubscribe = supabaseService.subscribeToActivitiesChanges(() {
      debugPrint('[Supabase Leaderboard] Realtime: activities changed, refreshing');
      fetchLeaderboard();
    });
  }

  /// Fetch today's leaderboard
  Future<void> fetchLeaderboard() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await activityRepository.getDailyLeaderboard();
      final entries = data
          .map((json) => LeaderboardEntry.fromJson(json))
          .toList();
      debugPrint('[Supabase Leaderboard] Loaded ${entries.length} entries');
      state = state.copyWith(
        isLoading: false,
        entries: entries,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }
}

/// Provider for leaderboard state with realtime subscription
final leaderboardProvider =
    StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
  final activityRepository = ref.watch(supabaseActivityRepositoryProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return LeaderboardNotifier(activityRepository, supabaseService);
});
