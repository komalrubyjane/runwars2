import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/leaderboard/leaderboard_screen.dart';
import '../../common/core/providers/auth_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../home/view_model/home_view_model.dart';
import 'settings_screen.dart';
import 'strava_edit_profile_screen.dart';

/// Strava-like colors (#FC4C02 orange, #CC4200 darker)
const Color _stravaOrange = Color(0xFFFC4C02);
const Color _stravaOrangeDark = Color(0xFFCC4200);

/// Strava-like user profile screen with Supabase user data
class StravaProfileScreen extends HookConsumerWidget {
  const StravaProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final authState = ref.watch(authProvider);
    final refreshKey = useState(0);

    return FutureBuilder<Map<String, dynamic>?>(
      key: ValueKey(refreshKey.value),
      future: supabaseUser != null
          ? SupabaseService().getUserProfile(supabaseUser.id)
          : Future.value(null),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final fullName =
            profile?['full_name'] as String? ?? authState.email ?? 'Runner';
        final totalDistance =
            (profile?['total_distance'] as num?)?.toDouble() ?? 0.0;
        final totalSteps = (profile?['total_steps'] as int?) ?? 0;
        return _ProfileContent(
          fullName: fullName,
          authState: authState,
          totalDistance: totalDistance,
          totalSteps: totalSteps,
          userId: supabaseUser?.id,
          refreshKey: refreshKey,
        );
      },
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  final String fullName;
  final dynamic authState;
  final double totalDistance;
  final int totalSteps;
  final String? userId;
  final ValueNotifier<int> refreshKey;

  const _ProfileContent({
    required this.fullName,
    required this.authState,
    required this.totalDistance,
    required this.totalSteps,
    required this.userId,
    required this.refreshKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<int>(
      future: userId != null
          ? SupabaseService().getUserActivitiesCount(userId!)
          : Future.value(0),
      builder: (context, snap) {
        final activities = snap.data ?? 0;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text('Profile'),
            elevation: 0,
            backgroundColor: _stravaOrange,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Strava-style header with orange gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_stravaOrange, _stravaOrangeDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 56,
                          color: _stravaOrange,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (authState.email != null)
                        Text(
                          authState.email!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),

                // Stats cards - Strava style
                Transform.translate(
                  offset: const Offset(0, -16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              '${totalDistance.toStringAsFixed(1)}',
                              'km',
                            ),
                            _buildStatItem('$totalSteps', 'steps'),
                            _buildStatItem('$activities', 'activities'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Daily Leaderboard
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LeaderboardScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.leaderboard),
                      label: const Text('Daily Leaderboard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _stravaOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Edit Profile & Share
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const StravaEditProfileScreen(),
                              ),
                            );
                            refreshKey.value++;
                          },
                          icon: const Icon(Icons.edit, size: 20),
                          label: const Text('Edit Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _stravaOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Share.share(
                            'Check out my Run Flutter Run stats! '
                            '$totalDistance km, $totalSteps steps.',
                          ),
                          icon: const Icon(Icons.share, size: 20),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _stravaOrange,
                            side: const BorderSide(color: _stravaOrange),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Start your first activity
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Switch to Record tab (index 0)
                        ref
                            .read(homeViewModelProvider.notifier)
                            .setCurrentIndex(2); // Record tab
                      },
                      icon: const Icon(Icons.directions_run),
                      label: const Text('Start Your First Activity'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _stravaOrange,
                        side: const BorderSide(color: _stravaOrange, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // This Week Stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'This Week',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildActivityRow(
                            Icons.straighten,
                            'Distance',
                            '${totalDistance.toStringAsFixed(1)} km',
                          ),
                          const Divider(height: 24),
                          _buildActivityRow(
                            Icons.timer_outlined,
                            'Time',
                            '0 min',
                          ),
                          const Divider(height: 24),
                          _buildActivityRow(
                            Icons.directions_run,
                            'Activities',
                            '$activities',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Recent Activities - empty state
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recent Activities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.directions_run,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No activities yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Start Your First Activity" to record a run',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _stravaOrange,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: _stravaOrange, size: 24),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
