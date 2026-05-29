import 'package:flutter/material.dart';

class ActivityDashboardScreen extends StatelessWidget {
  const ActivityDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity'),
          backgroundColor: Colors.black,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Color(0xFFC7F900),
            labelColor: Color(0xFFC7F900),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Liked'),
              Tab(text: 'Saved'),
              Tab(text: 'Chats'),
              Tab(text: 'Tickets'),
              Tab(text: 'Schedule'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PlaceholderTab(title: 'Images Liked', icon: Icons.favorite),
            _PlaceholderTab(title: 'Saved Items', icon: Icons.bookmark),
            _PlaceholderTab(title: 'Chat History', icon: Icons.chat),
            _PlaceholderTab(title: 'Tickets Bought', icon: Icons.confirmation_num),
            _PlaceholderTab(title: 'Schedule History', icon: Icons.calendar_month),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderTab({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade800),
          const SizedBox(height: 16),
          Text(
            'Your $title will appear here.',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
