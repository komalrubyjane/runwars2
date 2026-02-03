import 'package:run_flutter_run/core/services/supabase_service.dart';

/// Repository for handling activity-related database operations
class ActivityRepository {
  final SupabaseService supabaseService;

  ActivityRepository(this.supabaseService);

  /// Save a completed activity to the database
  Future<bool> saveActivity({
    required String userId,
    required double distance,
    required int steps,
    required int durationSeconds,
    required List<Map<String, dynamic>> pathPoints,
  }) async {
    try {
      await supabaseService.saveActivity(
        userId: userId,
        distance: distance,
        steps: steps,
        durationSeconds: durationSeconds,
        pathPoints: pathPoints,
      );
      return true;
    } catch (e) {
      print('Error saving activity: $e');
      return false;
    }
  }

  /// Get user's activities
  Future<List<Map<String, dynamic>>> getUserActivities(String userId) async {
    return await supabaseService.getUserActivities(userId);
  }

  /// Get activity details
  Future<Map<String, dynamic>?> getActivityDetails(String activityId) async {
    return await supabaseService.getActivityDetails(activityId);
  }

  /// Get today's leaderboard
  Future<List<Map<String, dynamic>>> getDailyLeaderboard() async {
    return await supabaseService.getDailyLeaderboard();
  }
}
