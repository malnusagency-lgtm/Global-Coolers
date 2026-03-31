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
                const SizedBox(height: 32),
                _buildQuickActions(context, l10n),
                const SizedBox(height: 32),
                _buildActivePickup(context, userProvider),
                const SizedBox(height: 32),
                _buildRecentActivitySection(l10n),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset('assets/images/logo.png', height: 16),
                const SizedBox(width: 8),
                Text(
                  l10n.translate('welcome'),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Text(
              userProvider.userName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: AppColors.textPrimary),
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
            const SizedBox(width: 8),
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
    );
  }

  Widget _buildQuickActions(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildActionCard(context, l10n.translate('schedule_pickup'), Icons.calendar_today_rounded, AppColors.primary, '/schedule-pickup'),
            const SizedBox(width: 12),
            _buildActionCard(context, 'Impact', Icons.trending_up_rounded, AppColors.secondary, '/impact-stats'),
            const SizedBox(width: 12),
            _buildActionCard(context, 'Leaderboard', Icons.leaderboard_rounded, AppColors.warning, '/leaderboard'),
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivePickup(BuildContext context, UserProvider user) {
    return FutureBuilder<List<dynamic>>(
      future: _supabaseService.getPickups(),
      builder: (context, snapshot) {
        final active = (snapshot.data ?? []).cast<Map<String, dynamic>?>().firstWhere((p) => p?['status'] == 'scheduled', orElse: () => null);
        if (active == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
          child: Row(
            children: [
              const Icon(Icons.local_shipping, color: AppColors.primary),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(active['waste_type'], style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(active['date'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              const Text('Scheduled', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentActivitySection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        FutureBuilder<List<dynamic>>(
          future: _supabaseService.getPickups(),
          builder: (context, snapshot) {
            final completed = (snapshot.data ?? []).where((p) => p['status'] == 'completed').toList();
            if (completed.isEmpty) return const Text('No recent pickups found.', style: TextStyle(color: AppColors.textSecondary));
            return Column(children: completed.map((p) => ActivityItem(title: '${p['waste_type']} Collected', timestamp: p['date'], points: p['points_awarded'] ?? 50, icon: Icons.check_circle, iconColor: AppColors.success, backgroundColor: Colors.white)).toList());
          },
        ),
      ],
    );
  }
}
