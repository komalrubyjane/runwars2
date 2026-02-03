import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/providers/leaderboard_provider.dart';
import '../core/utils/color_utils.dart';
import '../core/utils/ui_utils.dart';

class LeaderboardScreen extends HookConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardState = ref.watch(leaderboardProvider);

    return Scaffold(
      backgroundColor: ColorUtils.blueGreyDarker,
      appBar: AppBar(
        backgroundColor: ColorUtils.main,
        title: const Text('Daily Leaderboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.refresh(leaderboardProvider);
            },
          ),
        ],
      ),
      body: leaderboardState.isLoading
          ? Center(child: UIUtils.loader)
          : leaderboardState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error loading leaderboard',
                        style: TextStyle(color: ColorUtils.white),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.refresh(leaderboardProvider);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : leaderboardState.entries.isEmpty
                  ? Center(
                      child: Text(
                        'No activities yet today',
                        style: TextStyle(color: ColorUtils.white),
                      ),
                    )
                  : ListView.builder(
                      itemCount: leaderboardState.entries.length,
                      itemBuilder: (context, index) {
                        final entry = leaderboardState.entries[index];
                        final medal = index == 0
                            ? '🥇'
                            : index == 1
                                ? '🥈'
                                : index == 2
                                    ? '🥉'
                                    : '';

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          color: ColorUtils.greyDarker,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: ColorUtils.main,
                              child: Text(
                                medal.isNotEmpty ? medal : '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            title: Text(
                              entry.userName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              entry.email,
                              style: const TextStyle(color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${entry.distance.toStringAsFixed(2)} km',
                                  style: TextStyle(
                                    color: ColorUtils.main,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${entry.steps} steps',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
