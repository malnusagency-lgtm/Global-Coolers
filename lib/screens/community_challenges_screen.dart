import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/api_service.dart';

class CommunityChallengesScreen extends StatefulWidget {
  const CommunityChallengesScreen({super.key});

  @override
  State<CommunityChallengesScreen> createState() => _CommunityChallengesScreenState();
}

class _CommunityChallengesScreenState extends State<CommunityChallengesScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Location', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            Row(
                              children: [
                                Icon(Icons.location_on, color: AppColors.primary, size: 16),
                                const SizedBox(width: 4),
                                const Text('Nairobi, Kenya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Icon(Icons.keyboard_arrow_down, size: 18),
                              ],
                            ),
                          ],
                        ),
                        Consumer<UserProvider>(
                          builder: (context, userProvider, _) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.eco, color: AppColors.primary, size: 18),
                                const SizedBox(width: 4),
                                Text('${userProvider.ecoPoints}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Tab Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          _buildTab('Active', 0),
                          _buildTab('Upcoming', 1),
                          _buildTab('My\nChallenges', 2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _buildTabContent(),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.textPrimary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          if (index == 1) Navigator.pushNamed(context, '/schedule-pickup');
          if (index == 3) Navigator.pushNamed(context, '/profile');
        },
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)] : null,
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedTab == 0) {
      return Column(
        key: const ValueKey(0),
        children: [
          const SizedBox(height: 24),
          _buildFeaturedChallenge(),
          const SizedBox(height: 24),
          _buildDailyChallenge(),
        ],
      );
    } else if (_selectedTab == 1) {
      return Column(
        key: const ValueKey(1),
        children: [
          const SizedBox(height: 24),
          _buildUpcomingChallenge(),
          const SizedBox(height: 24),
          Center(
            child: Text('More upcoming challenges loading...', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      );
    } else {
      return Column(
        key: const ValueKey(2),
        children: [
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.history, size: 18),
              label: const Text('View Past Challenges'),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildFeaturedChallenge() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.grey.shade300,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Container(
              height: 220,
              width: double.infinity,
              color: Colors.green.shade100,
              child: const Center(child: Icon(Icons.image, size: 60, color: Colors.white54)),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                child: const Text('Active Now', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: const [
                    Icon(Icons.timer, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('Ends in 14h 30m', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Plastic-Free Weekend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('200 Pts', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Nairobi-wide • Community Event', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Participation Goal', style: TextStyle(fontSize: 13)),
                        Text('85%', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(value: 0.85, backgroundColor: Color(0xFFE0E0E0), color: AppColors.primary, minHeight: 8),
                    ),
                    const SizedBox(height: 6),
                    const Text('1,240 people joined', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [Text('Check In'), SizedBox(width: 8), Icon(Icons.arrow_forward, size: 18)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingChallenge() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Icon(Icons.eco, color: AppColors.primary, size: 32)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: const Text('Upcoming', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      const Text('+500 Pts', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Kibera Clean-Up Drive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Text('District 4 • Starts in 3 days', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A2E1A),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Join Early'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChallenge() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 130,
              width: double.infinity,
              color: Colors.green.shade50,
              child: Stack(
                children: [
                  const Center(child: Icon(Icons.delete_outline, size: 48, color: Colors.green)),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Daily Challenge', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Sort It Out: Plastic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('+50 Pts', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Scan 5 plastic bottles at your local collection\npoint today.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Your Progress', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('2/5', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(value: 0.4, backgroundColor: Color(0xFFE0E0E0), color: AppColors.primary, minHeight: 6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

