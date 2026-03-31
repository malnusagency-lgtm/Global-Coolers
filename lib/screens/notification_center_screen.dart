import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: AppColors.primary),
            onPressed: () {},
            tooltip: 'Mark all as read',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Activity'),
            Tab(text: 'System'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationList('All'),
          _buildNotificationList('Activity'),
          _buildNotificationList('System'),
        ],
      ),
    );
  }

  Widget _buildNotificationList(String filter) {
    // Simulated notification data
    final notifications = [
      {
        'title': 'Welcome to Global Coolers! 🌍',
        'desc': 'You\'ve received 500 Eco-Points as a signup bonus. Start recycling today!',
        'time': 'Just now',
        'icon': Icons.stars_rounded,
        'color': AppColors.primary,
        'isSystem': true,
      },
      {
        'title': 'Pickup Confirmed 🚛',
        'desc': 'A collector is on the way to pick up your plastic waste.',
        'time': '2 hours ago',
        'icon': Icons.local_shipping_outlined,
        'color': AppColors.info,
        'isSystem': false,
      },
      {
        'title': 'New Challenge Available! 🏆',
        'desc': 'Join the "Nairobi Clean-up" challenge and earn 1000 points.',
        'time': '1 day ago',
        'icon': Icons.emoji_events_outlined,
        'color': AppColors.warning,
        'isSystem': true,
      },
    ];

    final filtered = filter == 'All' 
        ? notifications 
        : filter == 'System' 
            ? notifications.where((n) => n['isSystem'] as bool).toList()
            : notifications.where((n) => !(n['isSystem'] as bool)).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final n = filtered[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: (n['color'] as Color).withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(n['icon'] as IconData, color: n['color'] as Color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(n['desc'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Text(n['time'] as String, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
