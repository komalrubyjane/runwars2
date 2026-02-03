import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../common/leaderboard/leaderboard_screen.dart';

/// Strava-like stats and leaderboards screen
class StravaStatsScreen extends HookConsumerWidget {
  const StravaStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stats & Leaderboards'),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: [
              Tab(text: 'My Stats', icon: Icon(Icons.bar_chart)),
              Tab(text: 'Segments', icon: Icon(Icons.route)),
              Tab(text: 'Leaderboard', icon: Icon(Icons.leaderboard)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMyStatsTab(),
            _buildSegmentsTab(),
            const LeaderboardScreen(), // Supabase daily leaderboard
          ],
        ),
      ),
    );
  }

  Widget _buildMyStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Week',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard('Distance', '0 km', Colors.blue),
              _buildStatCard('Activities', '0', Colors.green),
              _buildStatCard('Time', '0 min', Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'This Month',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard('Distance', '0 km', Colors.blue),
              _buildStatCard('Activities', '0', Colors.green),
              _buildStatCard('Time', '0 min', Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'All Time',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard('Distance', '0 km', Colors.blue),
              _buildStatCard('Activities', '0', Colors.green),
              _buildStatCard('Time', '0 min', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No segment activities yet',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            child: const Text('Create a Segment'),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildLeaderboardCategory('Longest Run', Icons.arrow_upward),
        const SizedBox(height: 16),
        _buildLeaderboardCategory('Most Activities', Icons.trending_up),
        const SizedBox(height: 16),
        _buildLeaderboardCategory('Elevation Gain', Icons.terrain),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCategory(String title, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              _buildLeaderboardRow(1, 'You', '0 km', isCurrentUser: true),
              const Divider(),
              _buildLeaderboardRow(2, 'Friend 1', '0 km'),
              const Divider(),
              _buildLeaderboardRow(3, 'Friend 2', '0 km'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardRow(
    int rank,
    String name,
    String value, {
    bool isCurrentUser = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            '#$rank',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                color: isCurrentUser ? Colors.green : Colors.black,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
