import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/strava_theme.dart';
import '../providers/nearby_users_provider.dart';

/// Section showing runners within 5 km with "Join me!" button.
class NearbyRunnersSection extends ConsumerWidget {
  const NearbyRunnersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nearbyUsersProvider);

    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nearby (within 5 km)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No other runners within 5 km. Pull down to refresh.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                TextButton.icon(
                  onPressed: () => ref.invalidate(nearbyUsersProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Nearby (within 5 km)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            SizedBox(
              height: 88,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final u = list[index];
                  return _NearbyCard(
                    name: u.fullName ?? 'Runner',
                    distanceKm: u.distanceKm,
                    onJoinMe: () => _sendJoinMe(context, ref, u.userId),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Could not load nearby runners: $e', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ),
    );
  }

  Future<void> _sendJoinMe(BuildContext context, WidgetRef ref, String toUserId) async {
    final from = SupabaseService().currentUser;
    if (from == null) return;
    try {
      await SupabaseService().createRunInvite(
        fromUserId: from.id,
        toUserId: toUserId,
        message: 'Join me for a run!',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join me! invite sent. They\'ll get a notification.')),
        );
      }
      ref.invalidate(nearbyUsersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }
}

class _NearbyCard extends StatelessWidget {
  final String name;
  final double distanceKm;
  final VoidCallback onJoinMe;

  const _NearbyCard({
    required this.name,
    required this.distanceKm,
    required this.onJoinMe,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: StravaTheme.orange.withValues(alpha: 0.2),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: StravaTheme.orange, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${distanceKm.toStringAsFixed(1)} km away', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onJoinMe,
              style: FilledButton.styleFrom(
                backgroundColor: StravaTheme.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Join me!'),
            ),
          ],
        ),
      ),
    );
  }
}
