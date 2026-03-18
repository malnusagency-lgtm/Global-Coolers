import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/notification_card.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({Key? key}) : super(key: key);

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
    // Mock data
    final notifications = [
      {
        'title': 'Pickup Completed',
        'message': 'Your organic waste pickup was successfully completed. You earned 50 points!',
        'time': '2 mins ago',
        'type': NotificationType.activity,
      },
      {
        'title': 'System Maintenance',
        'message': 'Scheduled maintenance on Oct 15th from 2AM to 4AM.',
        'time': '1 hr ago',
        'type': NotificationType.system,
      },
      {
        'title': 'New Challenge Available',
        'message': 'Join the "Zero Waste Weekend" challenge and earn double points!',
        'time': '5 hrs ago',
        'type': NotificationType.community,
        'actionLabel': 'Join Now',
      },
       {
        'title': 'Driver Arriving',
        'message': 'Driver John is 5 minutes away from your location.',
        'time': 'Yesterday',
        'type': NotificationType.alert,
      },
    ];

    // Filter logic (mock)
    final filteredNotifications = notifications.where((n) {
      if (filter == 'All') return true;
      if (filter == 'Activity') return n['type'] == NotificationType.activity || n['type'] == NotificationType.community;
      if (filter == 'System') return n['type'] == NotificationType.system || n['type'] == NotificationType.alert;
      return true;
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredNotifications.length,
      itemBuilder: (context, index) {
        final n = filteredNotifications[index];
        return NotificationCard(
          title: n['title'] as String,
          message: n['message'] as String,
          time: n['time'] as String,
          type: n['type'] as NotificationType,
          actionLabel: n['actionLabel'] as String?,
          onAction: () {},
        );
      },
    );
  }
}
