import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase service for authentication, database, and real-time operations
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  /// Uses Supabase client from main.dart initialization
  SupabaseClient get _client => Supabase.instance.client;

  SupabaseClient get client => _client;

  /// Get current authenticated user
  User? get currentUser => _client.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    return response;
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Create user profile in database
  Future<void> createUserProfile({
    required String userId,
    required String email,
    required String fullName,
  }) async {
    await _client.from('users').insert({
      'id': userId,
      'email': email,
      'full_name': fullName,
      'created_at': DateTime.now().toIso8601String(),
      'total_distance': 0.0,
      'total_steps': 0,
    });
  }

  /// Update user profile (full_name)
  Future<void> updateUserProfile({
    required String userId,
    required String fullName,
  }) async {
    await _client.from('users').update({
      'full_name': fullName,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Save activity to database
  Future<void> saveActivity({
    required String userId,
    required double distance,
    required int steps,
    required int durationSeconds,
    required List<Map<String, dynamic>> pathPoints,
  }) async {
    try {
      await _client.from('activities').insert({
        'user_id': userId,
        'distance': distance,
        'steps': steps,
        'duration_seconds': durationSeconds,
        'path_points': pathPoints,
        'created_at': DateTime.now().toIso8601String(),
        'date': DateTime.now().toIso8601String().split('T')[0],
      });

      // Update user's total stats
      await updateUserStats(userId, distance, steps);
    } catch (e) {
      print('Error saving activity: $e');
      rethrow;
    }
  }

  /// Update user statistics
  Future<void> updateUserStats(
    String userId,
    double distance,
    int steps,
  ) async {
    try {
      final userProfile = await getUserProfile(userId);
      if (userProfile != null) {
        final totalDistance = (userProfile['total_distance'] ?? 0.0) + distance;
        final totalSteps = (userProfile['total_steps'] ?? 0) + steps;

        await _client.from('users').update({
          'total_distance': totalDistance,
          'total_steps': totalSteps,
        }).eq('id', userId);
      }
    } catch (e) {
      print('Error updating user stats: $e');
    }
  }

  /// Get today's leaderboard
  Future<List<Map<String, dynamic>>> getDailyLeaderboard() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await _client
          .from('activities')
          .select('user_id, distance, steps, users(full_name, email)')
          .eq('date', today)
          .order('distance', ascending: false)
          .limit(100);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return [];
    }
  }

  /// Get count of user's activities
  Future<int> getUserActivitiesCount(String userId) async {
    try {
      final list = await _client
          .from('activities')
          .select()
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(list).length;
    } catch (e) {
      return 0;
    }
  }

  /// Get user's activities
  Future<List<Map<String, dynamic>>> getUserActivities(String userId) async {
    try {
      final response = await _client
          .from('activities')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching user activities: $e');
      return [];
    }
  }

  /// Get activity details with path points
  Future<Map<String, dynamic>?> getActivityDetails(String activityId) async {
    try {
      final response = await _client
          .from('activities')
          .select()
          .eq('id', activityId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error fetching activity details: $e');
      return null;
    }
  }

  /// Subscribe to activities table changes for real-time leaderboard updates.
  /// Call [onChanged] when INSERT, UPDATE, or DELETE occurs.
  /// Returns a function to unsubscribe.
  /// Note: Enable Realtime for the activities table in Supabase Dashboard:
  /// Database > Replication > add "activities" to the publication.
  void Function() subscribeToActivitiesChanges(void Function() onChanged) {
    final channel = _client
        .channel('activities-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'activities',
          callback: (_) => onChanged(),
        )
        .subscribe();

    return () {
      _client.removeChannel(channel);
    };
  }
}
