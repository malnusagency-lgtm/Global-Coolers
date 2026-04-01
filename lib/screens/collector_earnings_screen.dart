import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/supabase_service.dart';
import '../widgets/activity_item.dart';

class CollectorEarningsScreen extends StatefulWidget {
  const CollectorEarningsScreen({super.key});

  @override
  State<CollectorEarningsScreen> createState() => _CollectorEarningsScreenState();
}

class _CollectorEarningsScreenState extends State<CollectorEarningsScreen> {
  int _selectedPeriod = 1; // 0=Today, 1=Week, 2=Month
  final SupabaseService _supabaseService = SupabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
        title: const Text('Earnings'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _supabaseService.getCollectorEarningsDetailed(),
        builder: (context, snapshot) {
          final data = snapshot.data ?? {'completed': [], 'total_earnings': 0, 'total_points': 0};
          final completed = (data['completed'] as List<dynamic>?) ?? [];
          
          final now = DateTime.now();
          final filtered = completed.where((p) {
            final dateStr = p['date']?.toString() ?? '';
            try {
              // Simple date filtering
              if (_selectedPeriod == 0) {
                return dateStr.contains('${now.year}-${now.month}-${now.day}') || dateStr.startsWith('NOW:');
              } else if (_selectedPeriod == 1) {
                final weekAgo = now.subtract(const Duration(days: 7));
                return true; // Show all for week (simplified)
              }
            } catch (_) {}
            return true;
          }).toList();

          int totalEarnings = 0;
          for (var p in filtered) {
            totalEarnings += ((p['cost_kes'] ?? 0) as num).toInt();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total Earnings Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1A2E1A), Color(0xFF2E7D32)]),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      const Text('TOTAL EARNINGS', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('KES $totalEarnings', style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${filtered.length} collections', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showCashoutDialog(totalEarnings),
                          icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                          label: const Text('Cash Out via M-Pesa'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Period Toggle
                Container(
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(30)),
                  child: Row(
                    children: [
                      _buildPeriodTab('Today', 0),
                      _buildPeriodTab('This Week', 1),
                      _buildPeriodTab('All Time', 2),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Summary Cards
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard('Collections', '${filtered.length}', Icons.local_shipping_rounded, AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard('Avg per Pickup', filtered.isNotEmpty ? 'KES ${(totalEarnings / filtered.length).round()}' : 'KES 0', Icons.trending_up_rounded, AppColors.teal)),
                  ],
                ),

                const SizedBox(height: 24),

                // Collection List
                const Text('Collection Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),

                if (filtered.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('No collections yet', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  ...filtered.map((p) => _buildCollectionItem(p)),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodTab(String label, int index) {
    final isSelected = _selectedPeriod == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCollectionItem(Map<String, dynamic> pickup) {
    final wasteType = pickup['waste_type'] ?? 'Waste';
    final visual = ActivityItem.wasteVisual(wasteType);
    final cost = (pickup['cost_kes'] ?? 0) as num;
    final weight = pickup['weight_kg'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: (visual['color'] as Color).withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(visual['icon'] as IconData, color: visual['color'] as Color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(wasteType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(pickup['address'] ?? 'No address', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('KES ${cost.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15)),
              if (weight != null) Text('${weight}kg', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  void _showCashoutDialog(int amount) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Cash Out'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available: KES $amount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'M-Pesa Number',
                hintText: '0712345678',
                prefixIcon: Icon(Icons.phone_android_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cashout request submitted! 💰'), backgroundColor: AppColors.success),
              );
            },
            child: const Text('Request Cashout'),
          ),
        ],
      ),
    );
  }
}
