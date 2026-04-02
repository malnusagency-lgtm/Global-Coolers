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
        actions: [
          TextButton(
            onPressed: () async {
              await _supabaseService.markAllNotificationsRead();
              setState(() {});
            },
            child: const Text('Clear All', style: TextStyle(color: AppColors.primary, fontSize: 12)),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _supabaseService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          
          final notifications = snapshot.data ?? [];

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
                        final typeStr = n['type'] ?? 'info';
                        
                        // Map database types to enum
                        NotificationType type;
                        switch (typeStr) {
                          case 'success': type = NotificationType.success; break;
                          case 'warning': type = NotificationType.activity; break;
                          case 'error': type = NotificationType.alert; break;
                          default: type = NotificationType.info;
                        }

                        // Category filter
                        final category = _getCategoryFromType(typeStr);
                        if (_selectedCategory != 'All' && category != _selectedCategory) return const SizedBox.shrink();
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: NotificationCard(
                            title: n['title'] ?? 'Global Coolers',
                            message: n['message'] ?? '',
                            time: _formatTime(n['created_at']),
                            type: type,
                            onTap: () {
                              if (!(n['is_read'] ?? false)) {
                                _supabaseService.markNotificationRead(n['id'].toString());
                                setState(() {});
                              }
                            },
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

  String _getCategoryFromType(String type) {
    if (type == 'success' || type == 'warning') return 'Activity';
    return 'System';
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Now';
    try {
      final time = DateTime.parse(timestamp.toString());
      final diff = DateTime.now().difference(time);
      if (diff.inDays > 7) return '${time.day}/${time.month}/${time.year}';
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return 'Today';
    }
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
