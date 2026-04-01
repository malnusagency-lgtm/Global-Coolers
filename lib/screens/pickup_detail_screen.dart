import 'package:flutter/material.dart';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_colors.dart';
import '../services/supabase_service.dart';
import '../widgets/activity_item.dart';

class PickupDetailScreen extends StatefulWidget {
  const PickupDetailScreen({super.key});

  @override
  State<PickupDetailScreen> createState() => _PickupDetailScreenState();
}

class _PickupDetailScreenState extends State<PickupDetailScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  StreamSubscription? _statusSubscription;
  Map<String, dynamic>? _pickup;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pickup == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _pickup = Map<String, dynamic>.from(args);
        _listenToStatus();
      }
    }
  }

  void _listenToStatus() {
    if (_pickup == null || _pickup!['id'] == null) return;
    _statusSubscription = _supabaseService
        .streamPickupStatus(_pickup!['id'].toString())
        .listen((status) {
      if (mounted) setState(() => _pickup = status);
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pickup == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pickup Details')),
        body: const Center(child: Text('No pickup data')),
      );
    }

    final p = _pickup!;
    final wasteType = p['waste_type'] ?? 'Waste';
    final visual = ActivityItem.wasteVisual(wasteType);
    final Color typeColor = visual['color'];
    final IconData typeIcon = visual['icon'];
    final status = p['status'] ?? 'scheduled';
    final qrCode = p['qr_code_id'] ?? '';
    final hasCollector = p['collector_id'] != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Pickup Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: typeColor.withOpacity(0.12), shape: BoxShape.circle),
                    child: Icon(typeIcon, color: typeColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(wasteType, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(p['date'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      if (p['address'] != null)
                        Text(p['address'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 2),
                    ],
                  )),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Status Timeline
            const Text('Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildStatusTimeline(status),

            const SizedBox(height: 24),

            // Details Row
            Row(
              children: [
                if (p['weight_kg'] != null) Expanded(child: _buildInfoCard('Weight', '${p['weight_kg']} kg', Icons.scale_rounded, AppColors.teal)),
                if (p['cost_kes'] != null) ...[const SizedBox(width: 12), Expanded(child: _buildInfoCard('Cost', 'KES ${p['cost_kes']}', Icons.payments_rounded, AppColors.amber))],
                if (p['points_awarded'] != null) ...[const SizedBox(width: 12), Expanded(child: _buildInfoCard('Points', '+${p['points_awarded']}', Icons.stars_rounded, AppColors.primary))],
              ],
            ),

            // Collector Info
            if (hasCollector) ...[
              const SizedBox(height: 24),
              const Text('Collector', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: _supabaseService.getProfileById(p['collector_id']),
                builder: (context, snap) {
                  final collector = snap.data;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(
                            (collector?['full_name'] ?? 'C')[0].toUpperCase(),
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(collector?['full_name'] ?? 'Loading...', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(collector?['phone'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        )),
                        if (status != 'completed' && status != 'cancelled')
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.teal, size: 22),
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context, 
                                    '/chat', 
                                    arguments: {
                                      'pickupId': p['id'].toString(),
                                      'recipientName': collector?['full_name'] ?? 'Collector',
                                    }
                                  );
                                },
                                tooltip: 'Chat with Collector',
                              ),
                              if (status == 'in_transit' || status == 'accepted' || status == 'arrived')
                                ElevatedButton.icon(
                                  onPressed: () => Navigator.pushNamed(context, '/live-tracking', arguments: {
                                    'collectorId': p['collector_id'],
                                    'pickupId': p['id'].toString(),
                                    'qrCode': qrCode,
                                    'wasteType': wasteType,
                                  }),
                                  icon: const Icon(Icons.location_on_rounded, size: 16),
                                  label: const Text('Track', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],

            // QR Code
            if (qrCode.isNotEmpty && status != 'completed' && status != 'cancelled') ...[
              const SizedBox(height: 24),
              const Text('Your QR Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Show this to the collector for verification', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
                  ),
                  child: QrImageView(data: qrCode, size: 180, backgroundColor: Colors.white),
                ),
              ),
            ],

            // Photo
            if (p['photo_url'] != null) ...[
              const SizedBox(height: 24),
              const Text('Waste Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(p['photo_url'], height: 180, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 180,
                    color: Colors.grey.shade100,
                    child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                  ),
                ),
              ),
            ],

            // Rate Button
            if (status == 'completed' && p['rating'] == null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showRatingDialog(p),
                  icon: const Icon(Icons.star_rounded, size: 20),
                  label: const Text('Rate This Pickup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(String currentStatus) {
    final steps = [
      {'key': 'scheduled', 'label': 'Scheduled', 'icon': Icons.schedule_rounded},
      {'key': 'accepted', 'label': 'Claimed', 'icon': Icons.assignment_turned_in_rounded},
      {'key': 'in_transit', 'label': 'En Route', 'icon': Icons.local_shipping_rounded},
      {'key': 'arrived', 'label': 'Arrived', 'icon': Icons.location_on_rounded},
      {'key': 'completed', 'label': 'Completed', 'icon': Icons.check_circle_rounded},
    ];

    if (currentStatus == 'cancelled') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.error.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 12),
            const Text('This pickup was cancelled', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final statusOrder = ['scheduled', 'accepted', 'in_transit', 'arrived', 'completed'];
    final currentIdx = statusOrder.indexOf(currentStatus);

    return Column(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isDone = i <= currentIdx;
        final isCurrent = i == currentIdx;
        final color = isDone ? AppColors.primary : Colors.grey.shade300;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: isDone ? AppColors.primary.withOpacity(isCurrent ? 1 : 0.15) : Colors.grey.shade100,
                    shape: BoxShape.circle,
                    border: isCurrent ? Border.all(color: AppColors.primary, width: 2) : null,
                  ),
                  child: Icon(step['icon'] as IconData, size: 16, color: isDone ? (isCurrent ? Colors.white : AppColors.primary) : Colors.grey.shade400),
                ),
                if (i < steps.length - 1)
                  Container(width: 2, height: 32, color: i < currentIdx ? AppColors.primary.withOpacity(0.3) : Colors.grey.shade200),
              ],
            ),
            const SizedBox(width: 14),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                step['label'] as String,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isDone ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: isCurrent ? 15 : 14,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  void _showRatingDialog(Map<String, dynamic> pickup) {
    int selectedRating = 0;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text('Rate Your Pickup', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('How was your experience?', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setSheetState(() => selectedRating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 40,
                      color: i < selectedRating ? AppColors.amber : Colors.grey.shade300,
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add a comment (optional)',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedRating == 0 ? null : () async {
                    Navigator.pop(ctx);
                    try {
                      await _supabaseService.submitRating(
                        pickupId: pickup['id'].toString(),
                        rating: selectedRating,
                        comment: commentController.text.trim(),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Thanks for your feedback! ⭐'), backgroundColor: AppColors.success),
                        );
                        setState(() {});
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Submit Rating', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
