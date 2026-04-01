import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/user_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_localizations.dart';
import '../widgets/activity_item.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/impact_card.dart';
import '../services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final SupabaseService _supabaseService = SupabaseService();

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
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async { setState(() {}); },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(userProvider, l10n),
                const SizedBox(height: 24),
                ImpactCard(
                  points: userProvider.ecoPoints,
                  co2Saved: userProvider.totalWasteDiverted * 0.8,
                  onTap: () => Navigator.pushNamed(context, '/impact-stats'),
                ),
                const SizedBox(height: 28),
                _buildStreakCard(),
                const SizedBox(height: 28),
                _buildQuickActions(context, l10n),
                const SizedBox(height: 28),
                _buildScheduledPickups(context),
                const SizedBox(height: 28),
                _buildReferralCard(),
                const SizedBox(height: 28),
                _buildRecentActivitySection(l10n),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        role: userProvider.isCollector ? UserRole.collector : UserRole.resident,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) Navigator.pushNamed(context, '/schedule-pickup');
          if (index == 2) Navigator.pushNamed(context, '/rewards');
          if (index == 3) Navigator.pushNamed(context, '/profile');
        },
      ),

    );
  }

  Widget _buildHeader(UserProvider userProvider, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Image.asset('assets/images/logo.png', height: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.translate('welcome'),
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                userProvider.userName,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: -0.5),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.primaryGradient),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.transparent,
                child: Text(
                  userProvider.userName.isNotEmpty ? userProvider.userName[0].toUpperCase() : 'G', 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildActionCard(context, l10n.translate('schedule_pickup'), Icons.calendar_today_rounded, AppColors.primary, '/schedule-pickup'),
            const SizedBox(width: 10),
            _buildActionCard(context, 'Impact', Icons.eco_rounded, AppColors.teal, '/impact-stats'),
            const SizedBox(width: 10),
            _buildActionCard(context, 'Leaderboard', Icons.leaderboard_rounded, AppColors.amber, '/leaderboard'),
            const SizedBox(width: 10),
            _buildActionCard(context, 'Waste Guide', Icons.menu_book_rounded, AppColors.indigo, '/waste-guide'),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, String route) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title, 
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Scheduled Pickups with Cancel ──

  Widget _buildScheduledPickups(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _supabaseService.getPickups(),
      builder: (context, snapshot) {
        final scheduled = (snapshot.data ?? [])
            .cast<Map<String, dynamic>?>()
            .where((p) => p?['status'] == 'scheduled')
            .toList();

        if (scheduled.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Scheduled Pickups', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text('${scheduled.length} active', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ...scheduled.map((p) => _buildScheduledItem(p!)),
          ],
        );
      },
    );
  }

  Widget _buildScheduledItem(Map<String, dynamic> pickup) {
    final wasteType = pickup['waste_type'] ?? 'Waste';
    final visual = ActivityItem.wasteVisual(wasteType);
    final Color typeColor = visual['color'];
    final IconData typeIcon = visual['icon'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(typeIcon, color: typeColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(wasteType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text(pickup['date'] ?? '', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (pickup['address'] != null)
              Text(pickup['address'], style: TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                if (pickup['weight_kg'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('${(pickup['weight_kg'] as num).toDouble() % 1 == 0 ? (pickup['weight_kg'] as num).toInt() : pickup['weight_kg']}kg', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor)),
                  ),
                if (pickup['cost_kes'] != null && (pickup['cost_kes'] as num) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('KES ${pickup['cost_kes']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
              ],
            ),
          ])),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Scheduled', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _showCancelDialog(pickup),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded, size: 13, color: AppColors.error),
                      const SizedBox(width: 3),
                      Text('Cancel', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(Map<String, dynamic> pickup) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
          const SizedBox(width: 8),
          const Text('Cancel Pickup?'),
        ]),
        content: Text('Are you sure you want to cancel the ${pickup['waste_type']} pickup scheduled for ${pickup['date']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep It', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _supabaseService.cancelPickup(pickup['id'].toString());
                if (mounted) {
                  setState(() {}); // Refresh the list
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Pickup cancelled successfully'),
                      backgroundColor: AppColors.error,
                      action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancel Pickup', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 14),
        FutureBuilder<List<dynamic>>(
          future: _supabaseService.getPickups(),
          builder: (context, snapshot) {
            final completed = (snapshot.data ?? []).where((p) => p['status'] == 'completed').toList();
            if (completed.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Icon(Icons.recycling_rounded, size: 40, color: AppColors.primary.withOpacity(0.3)),
                    const SizedBox(height: 8),
                    const Text('No completed pickups yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const Text('Schedule your first pickup to get started!', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              );
            }
            return Column(
              children: completed.map((p) {
                final visual = ActivityItem.wasteVisual(p['waste_type'] ?? '');
                return ActivityItem(
                  title: '${p['waste_type']} Collected',
                  timestamp: p['date'] ?? '',
                  points: p['points_awarded'] ?? 50,
                  icon: visual['icon'],
                  iconColor: visual['color'],
                  backgroundColor: Colors.white,
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pushNamed(context, '/pickup-history'),
            child: const Text('View Full History →', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard() {
    return FutureBuilder<int>(
      future: _supabaseService.getUserStreak(),
      builder: (context, snapshot) {
        final streak = snapshot.data ?? 0;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  streak > 0 ? '🔥' : '❄️',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      streak > 0 ? '$streak-Week Streak!' : 'Start Your Streak',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF5D4037)),
                    ),
                    Text(
                      streak > 0
                          ? 'Keep recycling weekly to grow your streak'
                          : 'Schedule a pickup to begin earning streaks',
                      style: TextStyle(fontSize: 12, color: Colors.brown.shade300),
                    ),
                  ],
                ),
              ),
              if (streak >= 3)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('+${streak * 10} bonus', style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReferralCard() {
    return FutureBuilder<String>(
      future: _supabaseService.getReferralCode(),
      builder: (context, snapshot) {
        final code = snapshot.data ?? '';
        if (code.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE8EAF6), Color(0xFFC5CAE9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.indigo.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.indigo.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_rounded, color: AppColors.indigo, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Share & Earn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    const Text('Invite friends, earn 200 pts each!', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('Your code: $code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.indigo.withOpacity(0.7))),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // Share referral code
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Referral code: $code copied!'), backgroundColor: AppColors.success),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
