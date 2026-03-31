import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/supabase_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class CollectorDashboardScreen extends StatefulWidget {
  const CollectorDashboardScreen({super.key});

  @override
  State<CollectorDashboardScreen> createState() => _CollectorDashboardScreenState();
}

class _CollectorDashboardScreenState extends State<CollectorDashboardScreen> {
  int _currentNavIndex = 0;
  final SupabaseService _supabaseService = SupabaseService();
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      final userProvider = context.read<UserProvider>();
      if (userProvider.isOnline) {
        _supabaseService.updateLocationFromGps();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Collector Dashboard'),
        automaticallyImplyLeading: false, 
        actions: [
          _buildOnlineToggle(userProvider),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async { setState(() {}); },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBanner(userProvider),
                const SizedBox(height: 24),
                _buildStatsSection(),
                const SizedBox(height: 32),
                const Text('Assigned Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                _buildPickupQueue(userProvider),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: userProvider.isOnline ? FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/qr-scanner'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('Verify Pickup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        role: UserRole.collector,
        onTap: (index) {
          setState(() => _currentNavIndex = index);
          if (index == 2) Navigator.pushNamed(context, '/profile');
        },
      ),
    );
  }

  Widget _buildOnlineToggle(UserProvider provider) {
    return Row(
      children: [
        Text(provider.isOnline ? 'ONLINE' : 'OFFLINE', 
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: provider.isOnline ? AppColors.success : Colors.grey)),
        Switch(
          value: provider.isOnline,
          onChanged: (_) async {
            await provider.toggleOnlineStatus();
            if (provider.isOnline) {
              _supabaseService.updateLocationFromGps(); // Initial update when going online
            }
          },
          activeColor: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildStatusBanner(UserProvider provider) {
    if (provider.isOnline) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.success.withOpacity(0.2))),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 12),
            Expanded(child: Text('Active & Online. New assignments will appear here.', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.withOpacity(0.2))),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(child: Text('Offline. Go online to receive pickups.', style: TextStyle(color: AppColors.textPrimary, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _supabaseService.getCollectorStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'count': 0, 'earnings': 0};
        return Row(
          children: [
            Expanded(child: _buildStatCard('Today', '${stats['count']}', Icons.local_shipping, AppColors.primary)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard('KES', '${stats['earnings']}', Icons.account_balance_wallet, AppColors.warning)),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPickupQueue(UserProvider provider) {
    if (!provider.isOnline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade200),
              const SizedBox(height: 12),
              const Text('Queue hidden while offline', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: _supabaseService.getPendingPickups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final pickups = snapshot.data ?? [];
        if (pickups.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No assigned pickups found.')));

        return Column(
          children: pickups.asMap().entries.map((entry) {
            final p = entry.value;
            return _buildPickupItem(
              p['address'] ?? 'Address',
              '${p['waste_type']} • ${p['profiles']?['full_name'] ?? 'Resident'}',
              p['date'] ?? 'Scheduled',
              entry.key == 0,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPickupItem(String location, String details, String time, bool isNext) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNext ? AppColors.primary.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isNext ? Border.all(color: AppColors.primary, width: 1.5) : null,
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: isNext ? AppColors.primary : Colors.grey.shade300, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(location, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(details, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          Text(time.split(' ').first, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isNext ? AppColors.primary : AppColors.textSecondary)),
        ],
      ),
    );
  }
}
