import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/user_provider.dart';
import '../widgets/impact_card.dart';
import '../widgets/action_card.dart';
import '../widgets/activity_item.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
    // In a real app, you'd navigate here.
    // For prototype, we'll simulate navigation or just update state 
    // if screens are children of a scaffold with indexed stack.
    // However, given the plan is separate screens with named routes:
    if (index == 1) Navigator.pushNamed(context, '/schedule-pickup');
    if (index == 2) Navigator.pushNamed(context, '/rewards');
    if (index == 3) Navigator.pushNamed(context, '/profile');
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    if (userProvider.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome back,',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Habari, ${userProvider.userName}!',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none_rounded),
                      onPressed: () => Navigator.pushNamed(context, '/notifications'),
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Impact Card
              ImpactCard(
                points: userProvider.ecoPoints,
                co2Saved: 12, // Could also come from provider later
                onTap: () => Navigator.pushNamed(context, '/impact-stats'),
              ),
              
              const SizedBox(height: 32),
              
              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  ActionCard(
                    title: 'Schedule Pickup',
                    subtitle: 'Next: Tue, 12th',
                    icon: Icons.calendar_today_rounded,
                    color: AppColors.primary,
                    onTap: () => Navigator.pushNamed(context, '/schedule-pickup'),
                  ),
                  const SizedBox(width: 16),
                  ActionCard(
                    title: 'Report Issue',
                    subtitle: 'Illegal dumping?',
                    icon: Icons.campaign_rounded,
                    color: AppColors.warning, // Orange/Warning color
                    onTap: () => Navigator.pushNamed(context, '/report-issue'),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Track Collector Banner (Simulated as another action type or special card)
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/live-tracking'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_shipping_rounded, color: Colors.blue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Track Collector',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Driver is 5 mins away',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Live Map',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Recent Activity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Navigate to full activity list
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              const ActivityItem(
                title: 'Weekly Pickup Completed',
                timestamp: 'Yesterday, 9:45 AM',
                points: 50,
                icon: Icons.check_circle_rounded,
                iconColor: AppColors.success,
                backgroundColor: Color(0xFFE8F5E9), // Light green
              ),
              
              const ActivityItem(
                title: 'Plastic Recycling',
                timestamp: 'Tue 12th, 2:30 PM',
                points: 120,
                icon: Icons.recycling_rounded,
                iconColor: Color(0xFF9C27B0), // Purple
                backgroundColor: Color(0xFFF3E5F5), // Light purple
              ),
              
              // Bottom spacing for FAB/Nav bar
              const SizedBox(height: 80), 
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
