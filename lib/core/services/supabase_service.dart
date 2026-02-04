import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
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

  /// Update user profile (full_name, optionally profile_picture_url)
  Future<void> updateUserProfile({
    required String userId,
    required String fullName,
    String? profilePictureUrl,
  }) async {
    final updates = <String, dynamic>{
      'full_name': fullName,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (profilePictureUrl != null) updates['profile_picture_url'] = profilePictureUrl;
    await _client.from('users').update(updates).eq('id', userId);
  }

  /// Upload profile picture to Supabase Storage. Returns public URL.
  /// Requires bucket 'avatars' with public read. Path: userId/avatar.jpg
  Future<String?> uploadProfilePicture({
    required String userId,
    required List<int> imageBytes,
  }) async {
    try {
      final path = '$userId/avatar.jpg';
      await _client.storage.from('avatars').uploadBinary(
        path,
        Uint8List.fromList(imageBytes),
        fileOptions: const FileOptions(upsert: true),
      );
      return _client.storage.from('avatars').getPublicUrl(path);
    } catch (e) {
      if (kDebugMode) print('Error uploading profile picture: $e');
      return null;
    }
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

  /// Get recent activities from all users (for Groups/Community feed). Uses Supabase, not legacy API.
  Future<List<Map<String, dynamic>>> getCommunityActivities({int limit = 50}) async {
    try {
      final response = await _client
          .from('activities')
          .select('id, user_id, distance, steps, duration_seconds, path_points, created_at, date, users(full_name, email)')
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error fetching community activities: $e');
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

  // --- User locations (for nearby / 5 km) ---
  /// Upsert current user location. Requires table: user_locations (user_id, lat, lng, updated_at).
  Future<void> upsertUserLocation({
    required String userId,
    required double lat,
    required double lng,
  }) async {
    try {
      await _client.from('user_locations').upsert({
        'user_id': userId,
        'lat': lat,
        'lng': lng,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      if (kDebugMode) {
        print('Error upserting user location: $e');
      }
    }
  }

  /// Fetch all recent user locations (e.g. updated in last 24h). Filter by 5 km in Dart.
  /// Tries users(full_name) first; if FK fails, falls back to plain select (name can be from profile later).
  Future<List<Map<String, dynamic>>> getUserLocations() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
      final response = await _client
          .from('user_locations')
          .select('user_id, lat, lng, updated_at, users(full_name)')
          .gte('updated_at', cutoff);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user locations: $e');
      }
      try {
        final fallback = await _client
            .from('user_locations')
            .select('user_id, lat, lng, updated_at')
            .gte('updated_at', DateTime.now().subtract(const Duration(hours: 24)).toIso8601String());
        return List<Map<String, dynamic>>.from(fallback);
      } catch (_) {
        return [];
      }
    }
  }

  /// Get users within [radiusKm] of (lat, lng). Excludes [excludeUserId].
  Future<List<Map<String, dynamic>>> getUsersWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    required String excludeUserId,
  }) async {
    final list = await getUserLocations();
    final result = <Map<String, dynamic>>[];
    for (final row in list) {
      final uid = row['user_id'] as String?;
      if (uid == null || uid == excludeUserId) continue;
      final rowLat = (row['lat'] as num?)?.toDouble();
      final rowLng = (row['lng'] as num?)?.toDouble();
      if (rowLat == null || rowLng == null) continue;
      final d = _haversineKm(lat, lng, rowLat, rowLng);
      if (d <= radiusKm) {
        result.add({...row, 'distance_km': d});
      }
    }
    result.sort((a, b) => ((a['distance_km'] as double).compareTo(b['distance_km'] as double)));
    return result;
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // pi/180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a.clamp(0.0, 1.0))); // 2*R*asin, R=6371 km
  }

  // --- Run invites ("Join me!") ---
  /// Create a run invite. Requires table: run_invites (from_user_id, to_user_id, message, status, created_at).
  Future<void> createRunInvite({
    required String fromUserId,
    required String toUserId,
    String message = 'Join me for a run!',
  }) async {
    await _client.from('run_invites').insert({
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'message': message,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get run invites for the current user (where to_user_id = userId).
  Future<List<Map<String, dynamic>>> getRunInvitesForUser(String userId) async {
    try {
      final response = await _client
          .from('run_invites')
          .select()
          .eq('to_user_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(response);
      for (final row in list) {
        final fromId = row['from_user_id'] as String?;
        if (fromId != null) {
          final profile = await getUserProfile(fromId);
          if (profile != null) row['_sender_name'] = profile['full_name'];
        }
      }
      return list;
    } catch (e) {
      if (kDebugMode) print('Error fetching run invites: $e');
      return [];
    }
  }

  /// Subscribe to run_invites for [userId] (to_user_id = userId). Call [onInvite] when a new invite is received.
  void Function() subscribeToRunInvites(String userId, void Function(Map<String, dynamic> invite) onInvite) {
    final channel = _client
        .channel('run_invites-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'run_invites',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'to_user_id', value: userId),
          callback: (payload) {
            final newRow = payload.newRecord;
            final map = Map<String, dynamic>.from(newRow);
            onInvite(map);
          },
        )
        .subscribe();
    return () => _client.removeChannel(channel);
  }
}
