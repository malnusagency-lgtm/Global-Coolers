import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/user_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/activity_item.dart';

class PickupHistoryScreen extends StatefulWidget {
  const PickupHistoryScreen({super.key});

  @override
  State<PickupHistoryScreen> createState() => _PickupHistoryScreenState();
}

class _PickupHistoryScreenState extends State<PickupHistoryScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = ['All', 'Completed', 'Scheduled', 'Cancelled'];
  final SupabaseService _supabaseService = SupabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Pickup History'),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          const SizedBox(height: 8),
          Expanded(child: _buildHistoryList()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedFilter == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? null : Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Text(
                  _filters[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryList() {
    return FutureBuilder<List<dynamic>>(
      future: _supabaseService.getPickups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final allPickups = snapshot.data ?? [];
        final filtered = _filterPickups(allPickups);

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  _selectedFilter == 0
                      ? 'No pickups yet'
                      : 'No ${_filters[_selectedFilter].toLowerCase()} pickups',
                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text('Schedule your first pickup to get started!', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: filtered.length,
            itemBuilder: (context, index) => _buildHistoryItem(filtered[index]),
          ),
        );
      },
    );
  }

  List<dynamic> _filterPickups(List<dynamic> pickups) {
    switch (_selectedFilter) {
      case 1:
        return pickups.where((p) => p['status'] == 'completed').toList();
      case 2:
        return pickups.where((p) => p['status'] == 'scheduled' || p['status'] == 'accepted' || p['status'] == 'in_transit' || p['status'] == 'arrived').toList();
      case 3:
        return pickups.where((p) => p['status'] == 'cancelled').toList();
      default:
        return pickups.where((p) => p['status'] != 'archived').toList();
    }
  }

  Widget _buildHistoryItem(Map<String, dynamic> pickup) {
    final wasteType = pickup['waste_type'] ?? 'Waste';
    final visual = ActivityItem.wasteVisual(wasteType);
    final Color typeColor = visual['color'];
    final IconData typeIcon = visual['icon'];
    final status = pickup['status'] ?? 'unknown';
    final date = pickup['date'] ?? '';
    final weight = pickup['weight_kg'];
    final cost = pickup['cost_kes'];
    final points = pickup['points_awarded'];
    final address = pickup['address'];
    final photoUrl = pickup['photo_url'];

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'completed':
        statusColor = AppColors.success;
        statusLabel = 'Completed';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusLabel = 'Cancelled';
        statusIcon = Icons.cancel_rounded;
        break;
      case 'in_transit':
        statusColor = AppColors.info;
        statusLabel = 'In Transit';
        statusIcon = Icons.local_shipping_rounded;
        break;
      case 'arrived':
        statusColor = AppColors.teal;
        statusLabel = 'Arrived';
        statusIcon = Icons.location_on_rounded;
        break;
      case 'accepted':
        statusColor = AppColors.amber;
        statusLabel = 'Accepted';
        statusIcon = Icons.thumb_up_rounded;
        break;
      default:
        statusColor = AppColors.primary;
        statusLabel = 'Scheduled';
        statusIcon = Icons.schedule_rounded;
    }

    return GestureDetector(
      onTap: () => _showPickupDetail(pickup),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: typeColor.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(typeIcon, color: typeColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(wasteType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(date.toString().split(' ').first, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (address != null)
                    Text(address, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (weight != null)
                        _buildTag('${(weight as num).toDouble() % 1 == 0 ? (weight as num).toInt() : weight}kg', typeColor),
                      if (cost != null && (cost as num) > 0) ...[
                        const SizedBox(width: 6),
                        _buildTag('KES $cost', AppColors.primary),
                      ],
                      if (points != null && (points as num) > 0) ...[
                        const SizedBox(width: 6),
                        _buildTag('+$points pts', AppColors.amber),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 13, color: statusColor),
                  const SizedBox(width: 4),
                  Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  void _showPickupDetail(Map<String, dynamic> pickup) {
    Navigator.pushNamed(context, '/pickup-detail', arguments: pickup);
  }
}
