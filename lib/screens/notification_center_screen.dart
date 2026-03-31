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
                            time: n.time,
                            icon: n.icon,
                            color: n.color,
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
      time: 'Just now',
      icon: Icons.celebration,
      color: AppColors.primary,
      category: 'System',
    ));

    for (var item in data) {
      final status = item['status'];
      final wasteType = item['waste_type'];
      final isResident = !user.isCollector;

      if (isResident) {
        if (status == 'scheduled') {
          list.add(_NotificationData(
            title: 'Pickup Confirmed 🚛',
            message: 'Your $wasteType pickup is scheduled. We have assigned a collector nearby.',
            time: item['date'] ?? 'Upcoming',
            icon: Icons.schedule,
            color: AppColors.info,
            category: 'Activity',
          ));
        } else if (status == 'completed') {
          list.add(_NotificationData(
            title: 'Waste Collected! 🎉',
            message: 'Successfully recycled your $wasteType waste. EcoPoints have been credited.',
            time: 'Completed',
            icon: Icons.check_circle,
            color: AppColors.success,
            category: 'Activity',
          ));
        }
      } else {
        // Collector notifications
        if (status == 'scheduled') {
          list.add(_NotificationData(
            title: 'New Assignment 📍',
            message: 'A new $wasteType pickup at ${item['address']} has been assigned to you.',
            time: 'New',
            icon: Icons.local_shipping,
            color: AppColors.warning,
            category: 'Activity',
          ));
        }
      }
    }

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
  final String time;
  final IconData icon;
  final Color color;
  final String category;

  _NotificationData({
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.color,
    required this.category,
  });
}
