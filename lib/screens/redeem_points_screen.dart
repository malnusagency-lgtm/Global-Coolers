import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/user_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/bottom_nav_bar.dart';

class RedeemPointsScreen extends StatefulWidget {
  const RedeemPointsScreen({super.key});

  @override
  State<RedeemPointsScreen> createState() => _RedeemPointsScreenState();
}

class _RedeemPointsScreenState extends State<RedeemPointsScreen> {
  int _selectedCategory = 0;
  final List<String> _categories = ['All Rewards', 'Airtime', 'Energy', 'Vouchers'];
  final SupabaseService _supabaseService = SupabaseService();
  bool _isProcessing = false;

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
        title: const Text('Redeem Points'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceCard(userProvider),
                _buildFeaturedBanner(),
                const SizedBox(height: 24),
                _buildCategoryChips(),
                const SizedBox(height: 24),
                _buildRewardGrid(context, userProvider),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        role: userProvider.isCollector ? UserRole.collector : UserRole.resident,
        onTap: (index) {
          if (userProvider.isCollector) {
            if (index == 0) Navigator.pushReplacementNamed(context, '/collector-dashboard');
            if (index == 1) Navigator.pushNamed(context, '/pickup-history');
            if (index == 3) Navigator.pushNamed(context, '/profile');
          } else {
            if (index == 0) Navigator.pushReplacementNamed(context, '/home');
            if (index == 1) Navigator.pushNamed(context, '/schedule-pickup'); // ✅ Schedule tab for residents
            if (index == 3) Navigator.pushNamed(context, '/profile');
          }
        },
      ),
    );
  }

  Widget _buildBalanceCard(UserProvider user) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF2E7D32)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TOTAL BALANCE', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text('${user.ecoPoints}', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white)),
                   const SizedBox(width: 8),
                   const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Pts', style: TextStyle(color: Colors.white60, fontSize: 16, fontWeight: FontWeight.w600))),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.stars_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recommended for you', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade100)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔥 Energy Saver Pack', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                const Text('Solar Lamp + Rechargeable Battery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Redeem for 5,000 Pts'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Charity Donation Banner
          const Text('Make an Impact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade100)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🌳 Plant a Tree Campaign', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                const Text('Donate your points to local reforestation efforts.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donation successful! You planted 1 tree. 🌿'), backgroundColor: AppColors.success));
                  },
                  icon: const Icon(Icons.favorite, size: 18),
                  label: const Text('Donate 1,000 Pts'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedCategory == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: isSelected ? AppColors.primary : Colors.white, borderRadius: BorderRadius.circular(20), border: isSelected ? null : Border.all(color: Colors.grey.shade200)),
              child: Center(child: Text(_categories[index], style: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRewardGrid(BuildContext context, UserProvider user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FutureBuilder<List<dynamic>>(
        future: _supabaseService.getRewards(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final rewards = snapshot.data ?? [];
          if (rewards.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No rewards available at the moment.')));

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.75),
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final r = rewards[index];
              final int costVal = (r['points_cost'] ?? 0) is int ? r['points_cost'] : (r['points_cost'] as num).toInt();
              return _buildRewardCard(r['id'].toString(), r['title'], r['partner'], costVal, user.ecoPoints >= costVal);
            },
          );
        },
      ),
    );
  }

  Widget _buildRewardCard(String id, String title, String partner, int cost, bool canAfford) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Container(color: AppColors.primary.withOpacity(0.05), width: double.infinity, child: const Icon(Icons.redeem, color: AppColors.primary, size: 32))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(partner, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canAfford ? () => _showRedeemDialog(id, title, cost) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford ? AppColors.primary : Colors.grey.shade100, 
                      foregroundColor: canAfford ? Colors.white : Colors.grey,
                      elevation: 0, padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(canAfford ? '$cost Pts' : 'Locked', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRedeemDialog(String id, String title, int cost) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Redeem $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your M-Pesa registered number for fulfillment.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'M-Pesa Number', hintText: '0712345678'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.length < 10) return;
              Navigator.pop(context);
              _handleRedeem(id, cost, controller.text);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRedeem(String id, int cost, String mpesa) async {
    setState(() => _isProcessing = true);
    try {
      await _supabaseService.redeemReward(id, cost, mpesa);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent! Your reward is being processed via M-Pesa. 🎉'), backgroundColor: AppColors.success));
      context.read<UserProvider>().fetchProfile(); // Refresh points
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Redemption failed: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 24),
            Text('Processing request...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Confirming point balance with Supabase', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
