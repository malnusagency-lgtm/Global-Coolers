import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/activity_item.dart';
import '../services/supabase_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:latlong2/latlong.dart';

class CollectorDashboardScreen extends StatefulWidget {
  const CollectorDashboardScreen({super.key});

  @override
  State<CollectorDashboardScreen> createState() => _CollectorDashboardScreenState();
}

class _CollectorDashboardScreenState extends State<CollectorDashboardScreen> with SingleTickerProviderStateMixin {
  int _currentNavIndex = 0;
  final SupabaseService _supabaseService = SupabaseService();
  Timer? _locationUpdateTimer;
  bool _showNearbyPickups = false;
  bool _isLoadingNearby = false;
  List<dynamic> _nearbyPickups = [];
  final Set<String> _declinedPickups = {};
  
  // Real-time Request Stream
  bool _isShowingRequest = false;
  StreamSubscription? _poolSubscription;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _initPoolStream();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _poolSubscription?.cancel();
    super.dispose();
  }

  void _initPoolStream() {
    _poolSubscription = _supabaseService.streamUnassignedPickups().listen((pickups) async {
      final userProvider = context.read<UserProvider>();
      if (!userProvider.isOnline || pickups.isEmpty || _isShowingRequest) return;

      final pos = await _supabaseService.getCurrentPosition();
      if (pos == null) return;

      final distance = const Distance();
      final myPoint = LatLng(pos.latitude, pos.longitude);

      // Filter out declined pickups and anything > 25km away
      final availablePickups = pickups.where((p) {
        if (_declinedPickups.contains(p['id'].toString())) return false;
        
        if (p['latitude'] != null && p['longitude'] != null) {
          final pickupPoint = LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble());
          final d = distance.as(LengthUnit.Kilometer, myPoint, pickupPoint);
          if (d > 25.0) return false;
        }
        return true;
      }).toList();

      if (availablePickups.isNotEmpty && mounted && !_isShowingRequest) {
        final newRequest = availablePickups.first;
        _isShowingRequest = true; // SET IMMEDIATELY TO PREVENT DUPLICATES
        _showNewRequestOverlay(newRequest);
      }
    });
  }

  void _showNewRequestOverlay(Map<String, dynamic> pickup) {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_shipping_rounded, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 20),
            const Text('New Request Available!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(
              'A resident near you needs a ${pickup['waste_type']} collection.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                   const Icon(Icons.location_on_rounded, color: AppColors.error, size: 20),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       pickup['address'] ?? 'Nearby Location',
                       style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _declinedPickups.add(pickup['id'].toString());
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('Decline', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _handleClaim(pickup);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 8,
                      shadowColor: AppColors.primary.withOpacity(0.4),
                    ),
                    child: const Text('Accept & Start', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                _showSchedulePicker(pickup);
              },
              child: const Text('Schedule for Later', style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // ✅ Always reset flag when sheet closes, regardless of how it closed
      if (mounted) _isShowingRequest = false;
    });
  }

  Future<void> _handleClaim(Map<String, dynamic> pickup, {String? arrivalTime}) async {
    try {
      await _supabaseService.claimPickup(
        pickup['id'].toString(),
        initialStatus: arrivalTime == null ? 'in_transit' : 'accepted',
        scheduledArrival: arrivalTime,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pickup claimed! 🎉 It\'s now in your tasks.'), backgroundColor: AppColors.success),
        );
        // Refresh everything
        _loadNearbyPickups(); 
        setState(() {}); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Claim failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _startLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final userProvider = context.read<UserProvider>();
      if (userProvider.isOnline) {
        _supabaseService.updateLocationFromGps();
      }
    });
  }

  Future<void> _loadNearbyPickups() async {
    setState(() => _isLoadingNearby = true);
    try {
      final pos = await _supabaseService.getCurrentPosition();
      if (pos != null) {
         // Using the broadcast pool filter logic combined with proximity if service supports it
         // For now, we use the unassigned pickups stream converted to a list for this section
         final pickups = await _supabaseService.getUnassignedPickupsNearby(pos.latitude, pos.longitude);
         if (mounted) setState(() => _nearbyPickups = pickups);
      }
    } catch (e) {
      debugPrint('Load nearby error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingNearby = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Collector Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(userProvider.isOnline ? 'You are visible to residents' : 'You are currently offline', 
                 style: TextStyle(fontSize: 11, color: userProvider.isOnline ? AppColors.success : AppColors.textSecondary)),
          ],
        ),
        automaticallyImplyLeading: false, 
        actions: [
          _buildOnlineToggle(userProvider),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async { 
            setState(() {}); 
            if (_showNearbyPickups) _loadNearbyPickups();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBanner(userProvider),
                const SizedBox(height: 20),
                _buildStatsSection(userProvider),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/collector-earnings'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.indigo.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.indigo.withOpacity(0.15)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart_rounded, color: AppColors.indigo, size: 18),
                        SizedBox(width: 8),
                        Text('View Detailed Earnings Report →', style: TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (userProvider.isOnline) _buildFindNearbyButton(),
                if (_showNearbyPickups && userProvider.isOnline) ...[
                  const SizedBox(height: 20),
                  _buildNearbyPickupsSection(),
                ],
                const SizedBox(height: 24),
                const Text('Assigned Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 14),
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
        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        label: const Text('Verify Pickup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        role: UserRole.collector,
        onTap: (index) {
          if (index == 1) {
             Navigator.pushNamed(context, '/pickup-history');
          } else if (index == 2) {
             Navigator.pushNamed(context, '/rewards');
          } else if (index == 3) {
             Navigator.pushNamed(context, '/profile');
          } else {
            setState(() => _currentNavIndex = index);
          }
        },
      ),
    );
  }

  Widget _buildOnlineToggle(UserProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: provider.isOnline ? AppColors.success.withOpacity(0.08) : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: provider.isOnline ? AppColors.success : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(provider.isOnline ? 'ONLINE' : 'OFFLINE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Switch(
            value: provider.isOnline,
            onChanged: (val) => provider.toggleOnlineStatus(),
            activeColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(UserProvider provider) {
    final isOnline = provider.isOnline;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnline 
            ? [AppColors.success.withOpacity(0.1), AppColors.success.withOpacity(0.02)]
            : [AppColors.amber.withOpacity(0.1), AppColors.amber.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: (isOnline ? AppColors.success : AppColors.amber).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(isOnline ? Icons.check_circle_rounded : Icons.cloud_off_rounded, color: isOnline ? AppColors.success : AppColors.amber),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isOnline ? 'Active & Online' : 'Currently Offline', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(isOnline ? 'New requests will be broadcasted to you.' : 'Go online to start receiving tasks.', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildStatsSection(UserProvider userProvider) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _supabaseService.getCollectorStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'count': 0, 'earnings': 0};
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildStatCard('Collections', '${stats['count']}', Icons.local_shipping_rounded, AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Earnings (KES)', '${stats['earnings']}', Icons.account_balance_wallet_rounded, AppColors.amber)),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatCard('Total ECO Points', '${userProvider.ecoPoints}', Icons.eco_rounded, AppColors.success, isFullWidth: true),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color, {bool isFullWidth = false}) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFindNearbyButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _showNearbyPickups = !_showNearbyPickups);
        if (_showNearbyPickups) _loadNearbyPickups();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.teal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.teal.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.explore_rounded, color: AppColors.teal),
            const SizedBox(width: 12),
            const Expanded(child: Text('Find Nearby Pickups', style: TextStyle(fontWeight: FontWeight.bold))),
            Icon(_showNearbyPickups ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.teal),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyPickupsSection() {
    if (_isLoadingNearby) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.teal)));

    if (_nearbyPickups.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No unassigned pickups nearby.', style: TextStyle(color: AppColors.textSecondary))));
    }

    return Column(
      children: _nearbyPickups.map((p) => _buildNearbyCard(p)).toList(),
    );
  }

  Widget _buildNearbyCard(Map<String, dynamic> pickup) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickup['address'] ?? 'Nearby Pickup', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${pickup['waste_type']} ΓÇó ${pickup['weight_kg']}kg', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          )),
          ElevatedButton(
            onPressed: () => _handleClaim(pickup),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Claim'),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupQueue(UserProvider provider) {
    if (!provider.isOnline) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Assigned tasks are hidden while offline.', style: TextStyle(color: AppColors.textSecondary))));

    return FutureBuilder<List<dynamic>>(
      future: _supabaseService.getPendingPickups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final pickups = snapshot.data ?? [];
        if (pickups.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No active tasks. Claim one to begin.', style: TextStyle(color: AppColors.textSecondary))));
        
        return Column(
          children: pickups.map((p) => _buildTaskCard(p)).toList(),
        );
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> p) {
    final status = p['status'] ?? 'accepted';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: status == 'in_transit' ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['address'] ?? 'Task', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${p['profiles']?['full_name'] ?? 'Resident'} ΓÇó ${p['waste_type']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(onPressed: () => _supabaseService.launchMaps(p['latitude'], p['longitude']), icon: const Icon(Icons.directions_rounded, color: AppColors.primary)),
              IconButton(onPressed: () => Navigator.pushNamed(context, '/chat', arguments: {'pickupId': p['id'], 'recipientName': p['profiles']?['full_name']}), icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.teal)),
              const Spacer(),
              if (status == 'accepted') ...[
                TextButton(
                  onPressed: () => _cancelAssignment(p['id']),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.error)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () => _updateStatus(p['id'], 'in_transit'), child: const Text('Start Trip')),
              ] else if (status == 'in_transit')
                ElevatedButton(onPressed: () => _checkArrival(p), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white), child: const Text('I\'ve Arrived'))
              else if (status == 'arrived')
                ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/qr-scanner', arguments: {'pickupId': p['id'].toString()}), style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white), child: const Text('Scan Code'))
            ],
          )
        ],
      ),
    );
  }

  Future<void> _cancelAssignment(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
          SizedBox(width: 8),
          Text('Cancel Assignment?'),
        ]),
        content: const Text('Are you sure you want to cancel this pickup? This will return it to the queue for other collectors.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, keep it')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Yes, cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (confirm == true) {
      try {
        await _supabaseService.cancelPickupAssignment(id.toString());
        if (mounted) {
          _declinedPickups.add(id.toString()); // Local persistence skip
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignment cancelled.'), backgroundColor: AppColors.error));
          if (_showNearbyPickups) _loadNearbyPickups();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showSchedulePicker(Map<String, dynamic> pickup) async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time != null) _handleClaim(pickup, arrivalTime: time.format(context));
  }

  Future<void> _updateStatus(dynamic id, String status) async {
    await _supabaseService.updatePickupStatus(id.toString(), status);
    setState(() {});
  }

  Future<void> _checkArrival(Map<String, dynamic> p) async {
    final arrived = await _supabaseService.isNearLocation(p['latitude'], p['longitude']);
    if (!arrived) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are too far from the pickup location to mark as arrived.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    // ✅ Fixed: Just update status and refresh. DO NOT auto-push QR scanner.
    // Resident needs to receive the "Arrived" notification first before showing QR.
    await _updateStatus(p['id'], 'arrived');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resident has been notified you arrived! Tap "Scan Code" when they show you the QR.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
