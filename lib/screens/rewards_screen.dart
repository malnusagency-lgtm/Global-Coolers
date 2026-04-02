import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/reward_item.dart';
import '../widgets/bottom_nav_bar.dart';
import '../providers/user_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/badge_item.dart';
import '../services/supabase_service.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  int _currentIndex = 2; // Wallet/Rewards tab

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    final userProvider = context.read<UserProvider>();
    
    if (userProvider.isCollector) {
      if (index == 0) Navigator.pushNamed(context, '/collector-dashboard');
      if (index == 1) Navigator.pushNamed(context, '/pickup-history'); // History screen
      if (index == 3) Navigator.pushNamed(context, '/profile');
    } else {
      if (index == 0) Navigator.pushNamed(context, '/home');
      if (index == 1) Navigator.pushNamed(context, '/schedule-pickup');
      if (index == 3) Navigator.pushNamed(context, '/profile');
    }
  }


  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rewards & Impact'),
        automaticallyImplyLeading: false, // Managed by bottom nav
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Points Balance Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accent, AppColors.primary], // Lighter gradient
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'GREEN POINTS BALANCE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userProvider.ecoPoints.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/redeem-points');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Redeem Points'),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Badges & Achievements
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Badges',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    BadgeItem(
                      title: 'Eco Warrior',
                      icon: Icons.shield,
                      color: AppColors.primary,
                      isLocked: false, // Default unlocked
                    ),
                    const SizedBox(width: 16),
                    BadgeItem(
                      title: 'Top Recycler',
                      icon: Icons.recycling,
                      color: AppColors.info,
                      isLocked: userProvider.totalCollections < 50,
                    ),
                    const SizedBox(width: 16),
                    BadgeItem(
                      title: 'Community',
                      icon: Icons.people,
                      color: AppColors.warning,
                      isLocked: userProvider.ecoPoints < 1000,
                    ),
                    const SizedBox(width: 16),
                    BadgeItem(
                      title: 'Super Saver',
                      icon: Icons.savings,
                      color: AppColors.success,
                      isLocked: userProvider.totalCollections < 100,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Redeem
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rewards for You',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/redeem-points');
                    },
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              FutureBuilder<List<dynamic>>(
                future: SupabaseService().getRewards(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  final rewards = snapshot.data ?? [];
                  if (rewards.isEmpty) {
                    return Container(
                      width: MediaQuery.of(context).size.width - 48,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.redeem_outlined, size: 48, color: Colors.grey.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          const Text('No rewards available', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Check back soon for new offers!', style: TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,

                    child: Row(
                      children: rewards.map((reward) {
                        return RewardItem(
                          title: reward['title'],
                          subtitle: reward['partner'] ?? 'Global Coolers',
                          points: reward['cost'],
                          imageAsset: '',
                          imageUrl: reward['image_url'],
                          iconName: reward['image_url'] == null ? reward['icon_name'] : null,
                          colorHex: reward['color_hex'],
                          onRedeem: () async {
                            final success = await userProvider.redeemReward(
                              reward['cost'] as int,
                              rewardId: reward['id'].toString(), // Adjust based on schema
                            );
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Successfully redeemed ${reward['title']}!')),
                              );
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to redeem reward. Please check your points.')),
                              );
                            }
                          },
                          canAfford: userProvider.ecoPoints >= reward['cost'],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        role: userProvider.isCollector ? UserRole.collector : UserRole.resident,
        onTap: _onNavTap,
      ),

    );
  }
}
