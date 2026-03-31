import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/user_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_localizations.dart';
import '../widgets/activity_item.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/impact_card.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Future<List<dynamic>>? _pickupsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pickupsFuture == null) {
      final userId = context.read<UserProvider>().userId;
      if (userId.isNotEmpty) {
        _pickupsFuture = ApiService.getPickups(userId);
      } else {
        _pickupsFuture = Future.value([]);
      }
    }
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 1) Navigator.pushNamed(context, '/schedule-pickup');
    if (index == 2) Navigator.pushNamed(context, '/rewards');
    if (index == 3) Navigator.pushNamed(context, '/profile');
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final l10n = AppLocalizations.of(context);

    if (userProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: _pickupsFuture ?? Future.value([]),
          builder: (context, snapshot) {
            final pickups = snapshot.data ?? [];
            final activePickup = pickups.isEmpty ? null : pickups.cast<Map<String, dynamic>?>().firstWhere((p) => p?['status'] == 'scheduled', orElse: () => null);
            final recentActivity = pickups.where((p) => p['status'] == 'completed').toList();

            return SingleChildScrollView(
              child: Padding(
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
                            Text(
                              l10n.translate('welcome'),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                            ),
                            Text(
                              userProvider.userName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/notifications'),
                              child: Container(
                                padding: const EdgeInsets.all(10),
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
                                child: const Icon(Icons.notifications_none, color: AppColors.textPrimary, size: 22),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Consumer<LocaleProvider>(
                              builder: (context, localeProvider, _) {
                                final isEnglish = localeProvider.locale.languageCode == 'en';
                                return GestureDetector(
                                  onTap: () => localeProvider.toggleLocale(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      isEnglish ? 'EN' : 'SW',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                userProvider.userName.isNotEmpty ? userProvider.userName[0].toUpperCase() : 'G', 
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Impact Card
                    ImpactCard(
                      points: userProvider.ecoPoints,
                      co2Saved: userProvider.totalWasteDiverted.toDouble(),
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
                    SizedBox(
                      height: 110,
                      child: Row(
                        children: [
                          _buildActionCard(context, l10n.translate('schedule_pickup'), Icons.calendar_today_rounded, AppColors.primary, '/schedule-pickup'),
                          const SizedBox(width: 12),
                          _buildActionCard(context, l10n.translate('report_issue'), Icons.report_problem_outlined, AppColors.warning, '/report-issue'),
                          const SizedBox(width: 12),
                          _buildActionCard(context, 'Guide', Icons.menu_book_rounded, AppColors.info, '/waste-guide'),
                          const SizedBox(width: 12),
                          _buildActionCard(context, l10n.translate('community'), Icons.people_rounded, const Color(0xFF9C27B0), '/challenges'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Active Pickup
                    if (activePickup != null)
                      GestureDetector(
                        onTap: () {
                          final collectorId = activePickup['collector_id'];
                          if (collectorId == null || collectorId.toString().isEmpty || activePickup['status'] == 'scheduled') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('A collector has not been assigned yet.')),
                            );
                            return;
                          }
                          Navigator.pushNamed(
                            context, 
                            '/live-tracking',
                            arguments: {'collectorId': collectorId}
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.local_shipping, color: AppColors.primary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activePickup['waste_type'] ?? activePickup['wasteType'] ?? 'Active Pickup',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      activePickup['date'] ?? 'Scheduled',
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
                                  color: (activePickup['collector_id'] == null) ? Colors.grey.shade400 : Colors.blue,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  (activePickup['collector_id'] == null) ? 'Waiting...' : 'Live Map',
                                  style: const TextStyle(
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
                          onTap: () {},
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

                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator())
                    else if (recentActivity.isEmpty)
                      const ActivityItem(
                        title: 'No recent activity',
                        timestamp: 'Start recycling to earn points!',
                        points: 0,
                        icon: Icons.info_outline,
                        iconColor: Colors.grey,
                        backgroundColor: Color(0xFFF5F5F5),
                      )
                    else
                      ...recentActivity.map((p) => ActivityItem(
                            title: '${p['waste_type'] ?? p['wasteType'] ?? 'Pickup'} Completed',
                            timestamp: p['date'] ?? 'Recently',
                            points: p['points_awarded'] ?? 50,
                            icon: Icons.check_circle_rounded,
                            iconColor: AppColors.success,
                            backgroundColor: const Color(0xFFE8F5E9),
                          )),

                    // Bottom spacing for nav bar
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, String route) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
