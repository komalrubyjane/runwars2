import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/strava_theme.dart';
import '../../community/screens/community_screen.dart';
import '../../maps/screens/strava_maps_screen.dart';
import '../../new_activity/screens/strava_tracking_screen.dart';
import '../../settings/screens/strava_profile_screen.dart';
import '../view_model/home_view_model.dart';
import '../screens/strava_feed_screen.dart';

/// Strava-style 5 tabs: Home, Maps, Record, Groups, You
class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  static const _tabs = [
    _Tab(Icons.home_outlined, Icons.home, 'Home'),
    _Tab(Icons.map_outlined, Icons.map, 'Maps'),
    _Tab(Icons.play_circle_outline, Icons.play_circle_filled, 'Record'),
    _Tab(Icons.groups_outlined, Icons.groups, 'Groups'),
    _Tab(Icons.person_outline, Icons.person, 'You'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final notifier = ref.read(homeViewModelProvider.notifier);
    final index = state.currentIndex.clamp(0, 4);

    final bodies = [
      const StravaFeedScreen(),
      const StravaMapsScreen(),
      const StravaTrackingScreen(),
      CommunityScreen(),
      const StravaProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: bodies[index]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: StravaTheme.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(5, (i) {
                final t = _tabs[i];
                final selected = i == index;
                return InkWell(
                  onTap: () => notifier.setCurrentIndex(i),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? t.selectedIcon : t.icon,
                          size: 26,
                          color: selected ? StravaTheme.orange : StravaTheme.grey600,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? StravaTheme.orange : StravaTheme.grey600,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _Tab(this.icon, this.selectedIcon, this.label);
}
