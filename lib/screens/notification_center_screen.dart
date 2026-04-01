import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/notification_card.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notification Center'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<dynamic>>(
        // Both roles benefit from seeing their pickups/assignments history
        future: userProvider.isCollector 
            ? _supabaseService.getPendingPickups() 
            : _supabaseService.getPickups(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          
          final data = snapshot.data ?? [];
          final notifications = _generateNotifications(data, userProvider);

          return Column(
            children: [
              _buildCategoryTabs(),
              Expanded(
                child: notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final n = notifications[index];
                        if (_selectedCategory != 'All' && n.category != _selectedCategory) return const SizedBox.shrink();
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: NotificationCard(
                            title: n.title,
                            message: n.message,
                            time: n.timeFormatted,
                            icon: n.icon,
                            color: n.color,
                            type: n.type,
                          ),
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_NotificationData> _generateNotifications(List<dynamic> data, UserProvider user) {
    List<_NotificationData> list = [];

    // System welcome notification
    list.add(_NotificationData(
      title: 'Welcome to Global Coolers',
      message: user.isCollector 
          ? 'You are now a verified collector. Go online to start receiving waste pickup assignments!' 
          : 'Thank you for joining the green movement! Your first 500 EcoPoints have been added.',
      timestamp: DateTime.now().subtract(const Duration(days: 7)),
      icon: Icons.celebration,
      color: AppColors.primary,
      category: 'System',
      type: NotificationType.system,
    ));

    for (var item in data) {
      final status = item['status'];
      final wasteType = item['waste_type'];
      final isResident = !user.isCollector;
      
      DateTime eventTime;
      try {
        eventTime = DateTime.parse(item['created_at'] ?? DateTime.now().toIso8601String());
      } catch (e) {
        eventTime = DateTime.now();
      }

      if (isResident) {
        if (status == 'scheduled') {
          list.add(_NotificationData(
            title: 'Pickup Scheduled 🚛',
            message: 'Your $wasteType pickup is scheduled for ${item['date'] ?? 'upcoming'}.',
            timestamp: eventTime,
            icon: Icons.schedule,
            color: AppColors.info,
            category: 'Activity',
            type: NotificationType.activity,
          ));
        } else if (status == 'in_transit') {
          list.add(_NotificationData(
             title: 'Driver on the Way! 📍',
             message: 'A collector has accepted your immediate request.',
             timestamp: eventTime.add(const Duration(minutes: 5)),
             icon: Icons.local_shipping,
             color: Colors.orange,
             category: 'Activity',
             type: NotificationType.activity,
          ));
        } else if (status == 'accepted') {
          list.add(_NotificationData(
             title: 'Collector Confirmed',
             message: 'Collector agreed to arrive at ${item['scheduled_arrival'] ?? 'soon'}.',
             timestamp: eventTime.add(const Duration(minutes: 5)),
             icon: Icons.handshake,
             color: AppColors.primary,
             category: 'Activity',
             type: NotificationType.activity,
          ));
        } else if (status == 'completed') {
          list.add(_NotificationData(
            title: 'Waste Collected! 🎉',
            message: 'Successfully recycled your $wasteType waste. EcoPoints have been credited.',
            timestamp: eventTime.add(const Duration(hours: 1)),
            icon: Icons.check_circle,
            color: AppColors.success,
            category: 'Activity',
            type: NotificationType.success,
          ));
        }
      } else {
        // Collector notifications
        if (status == 'scheduled' || status == 'accepted' || status == 'in_transit') {
          list.add(_NotificationData(
            title: 'New Assignment 📍',
            message: 'A new $wasteType pickup at ${item['address']} has been assigned to you.',
            timestamp: eventTime,
            icon: Icons.local_shipping,
            color: AppColors.warning,
            category: 'Activity',
            type: NotificationType.activity,
          ));
        }
      }
    }

    // Sort descending by time
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Widget _buildCategoryTabs() {
    final categories = ['All', 'Activity', 'System'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: categories.map((cat) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text(cat),
            selected: _selectedCategory == cat,
            onSelected: (val) => setState(() => _selectedCategory = cat),
            selectedColor: AppColors.primary.withOpacity(0.1),
            labelStyle: TextStyle(
              color: _selectedCategory == cat ? AppColors.primary : AppColors.textSecondary,
              fontWeight: _selectedCategory == cat ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('All caught up!', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _NotificationData {
  final String title;
  final String message;
  final DateTime timestamp;
  final IconData icon;
  final Color color;
  final String category;
  final NotificationType type;

  String get timeFormatted {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays > 7) return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hrs ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mins ago';
    return 'Just now';
  }

  _NotificationData({
    required this.title,
    required this.message,
    required this.timestamp,
    required this.icon,
    required this.color,
    required this.category,
    required this.type,
  });
}
