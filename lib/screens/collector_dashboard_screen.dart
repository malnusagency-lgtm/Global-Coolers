import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/activity_item.dart';
import '../services/supabase_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

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
  List<Map<String, dynamic>> _nearbyPickups = [];
  late TabController _tabController;
  
  // Real-time Request Stream
  bool _isShowingRequest = false;
  StreamSubscription? _requestSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _startLocationUpdates();
    _initRequestStream();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _requestSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _initRequestStream() {
    _requestSubscription = _supabaseService.streamUnassignedPickups().listen((pickups) {
      final userProvider = context.read<UserProvider>();
      if (userProvider.isOnline && pickups.isNotEmpty && !_isShowingRequest) {
        final newRequest = pickups.first;
        _showNewRequestOverlay(newRequest);
      }
    });
  }

  void _showNewRequestOverlay(Map<String, dynamic> pickup) {
    if (!mounted) return;
    _isShowingRequest = true;
    
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            const Text('New Collection Request!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('A resident near you has requested a ${pickup['waste_type']} pickup.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _isShowingRequest = false;
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      _isShowingRequest = false;
                      Navigator.pop(context);
                      await _handleAcceptRequest(pickup, immediate: true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Accept Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  _isShowingRequest = false;
                  Navigator.pop(context);
                  _handleRespondByScheduling(pickup);
                },
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text('Respond by Scheduling'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );

  }

  Future<void> _handleAcceptRequest(Map<String, dynamic> pickup, {bool immediate = true}) async {
    try {
      await _supabaseService.acceptPickup(pickup['id'].toString(), immediate: immediate);
      
      if (immediate) {
        final lat = (pickup['latitude'] as num?)?.toDouble();
        final lng = (pickup['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          await _supabaseService.launchMaps(lat, lng);
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pickup accepted!'), backgroundColor: AppColors.success));
        setState(() {}); // Refresh list
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _handleRespondByScheduling(Map<String, dynamic> pickup) async {
    final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (pickedTime != null) {
      final arrivalTime = pickedTime.format(context);
      try {
        await _supabaseService.acceptPickup(pickup['id'].toString(), immediate: false, arrivalTime: arrivalTime);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Confirmed for $arrivalTime.'), backgroundColor: AppColors.success));
          setState(() {});
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _startLocationUpdates() {
    // Update GPS every 30 seconds when online (for real-time tracking)
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
        final nearby = await _supabaseService.getNearbyScheduledPickups(
          pos.latitude, pos.longitude, radiusKm: 15,
        );
        if (mounted) setState(() => _nearbyPickups = nearby);
      }
    } catch (e) {
      debugPrint('Load nearby error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingNearby = false);
    }
  }

  Future<void> _claimPickup(Map<String, dynamic> pickup) async {
    try {
      await _supabaseService.claimPickup(pickup['id'].toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pickup claimed! 🎉 It\'s now in your task list.'), backgroundColor: AppColors.success),
        );
        _loadNearbyPickups(); // Refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
                _buildStatsSection(),
                const SizedBox(height: 24),
                // Find Nearby Button
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
          setState(() => _currentNavIndex = index);
          if (index == 2) Navigator.pushNamed(context, '/profile');
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
          Text(
            provider.isOnline ? 'ONLINE' : 'OFFLINE', 
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: provider.isOnline ? AppColors.success : Colors.grey, letterSpacing: 0.5),
          ),
          Switch(
            value: provider.isOnline,
            onChanged: (_) async {
              try {
                await provider.toggleOnlineStatus();
                if (provider.isOnline) {
                  _supabaseService.updateLocationFromGps();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString().replaceAll('Exception: ', '')),
                    backgroundColor: AppColors.error,
                  ));
                }
              }
            },
            activeColor: AppColors.success,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),

        ],
      ),
    );
  }

  Widget _buildStatusBanner(UserProvider provider) {
    if (provider.isOnline) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.success.withOpacity(0.08), AppColors.success.withOpacity(0.03)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.success.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active & Online', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                Text('New assignments will appear below.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            )),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.amber.withOpacity(0.08), AppColors.amber.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.amber.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.amber.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.cloud_off_rounded, color: AppColors.amber, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Offline', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              Text('Go online to receive pickups.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          )),
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
            Expanded(child: _buildStatCard('Collections', '${stats['count']}', Icons.local_shipping_rounded, AppColors.primary, AppColors.primaryGradient)),
            const SizedBox(width: 14),
            Expanded(child: _buildStatCard('Earnings (KES)', '${stats['earnings']}', Icons.account_balance_wallet_rounded, AppColors.amber, AppColors.amberGradient)),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color, List<Color> gradient) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ── Find Nearby Pickups ──

  Widget _buildFindNearbyButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _showNearbyPickups = !_showNearbyPickups);
        if (_showNearbyPickups) _loadNearbyPickups();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _showNearbyPickups 
              ? [AppColors.teal.withOpacity(0.12), AppColors.teal.withOpacity(0.06)]
              : [AppColors.teal.withOpacity(0.08), AppColors.teal.withOpacity(0.03)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.teal.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.teal.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showNearbyPickups ? Icons.explore_rounded : Icons.explore_outlined, 
                color: AppColors.teal, size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Find Nearby Pickups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                Text(
                  _showNearbyPickups ? 'Tap to hide • Showing within 15km' : 'Discover unassigned pickups near you',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            )),
            Icon(
              _showNearbyPickups ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, 
              color: AppColors.teal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyPickupsSection() {
    if (_isLoadingNearby) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(color: AppColors.teal),
      ));
    }

    if (_nearbyPickups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(Icons.location_searching_rounded, size: 40, color: AppColors.teal.withOpacity(0.3)),
            const SizedBox(height: 8),
            const Text('No nearby pickups found', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const Text('Check back soon or increase your search radius', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Nearby (${_nearbyPickups.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: _loadNearbyPickups,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 14, color: AppColors.teal),
                    const SizedBox(width: 4),
                    const Text('Refresh', style: TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._nearbyPickups.map((p) => _buildNearbyPickupCard(p)),
      ],
    );
  }

  Widget _buildNearbyPickupCard(Map<String, dynamic> pickup) {
    final wasteType = pickup['waste_type'] ?? 'Waste';
    final visual = ActivityItem.wasteVisual(wasteType);
    final Color typeColor = visual['color'];
    final IconData typeIcon = visual['icon'];
    final distance = (pickup['distance_km'] as double).toStringAsFixed(1);
    final isMine = pickup['is_mine'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isMine ? AppColors.primary.withOpacity(0.3) : AppColors.teal.withOpacity(0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: typeColor.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(typeIcon, color: typeColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(wasteType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${distance}km', style: const TextStyle(fontSize: 10, color: AppColors.teal, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                pickup['address'] ?? 'Address not provided',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${pickup['profiles']?['full_name'] ?? 'Resident'} • ${(pickup['date'] ?? '').toString().split(' ').first}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          )),
          const SizedBox(width: 8),
          if (pickup['latitude'] != null && pickup['longitude'] != null)
            IconButton(
              icon: const Icon(Icons.directions_rounded, color: AppColors.primary, size: 24),
              onPressed: () => _supabaseService.launchMaps(
                (pickup['latitude'] as num).toDouble(),
                (pickup['longitude'] as num).toDouble(),
              ),
              tooltip: 'Navigate',
            ),
          const SizedBox(width: 4),
          if (isMine)

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Yours', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
            )
          else
            GestureDetector(
              onTap: () => _showClaimDialog(pickup),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.tealGradient),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppColors.teal.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: const Text('Claim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  void _showClaimDialog(Map<String, dynamic> pickup) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.assignment_turned_in_rounded, color: AppColors.teal, size: 24),
          const SizedBox(width: 8),
          const Text('Claim Pickup?'),
        ]),
        content: Text('Claim this ${pickup['waste_type']} pickup at ${pickup['address'] ?? 'the given location'}? It will be added to your assigned tasks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _claimPickup(pickup);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text('Claim It', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Assigned Task Queue ──

  Widget _buildPickupQueue(UserProvider provider) {
    if (!provider.isOnline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey.shade300),
              ),
              const SizedBox(height: 12),
              const Text('Queue hidden while offline', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
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
        if (pickups.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 40, color: AppColors.primary.withOpacity(0.3)),
                  const SizedBox(height: 8),
                  const Text('No assigned pickups', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                  const Text('Use "Find Nearby" to discover pickups', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          );
        }

        return Column(
          children: pickups.asMap().entries.map((entry) {
            final p = entry.value;
            return _buildPickupItem(p, entry.key == 0);
          }).toList(),
        );
      },
    );
  }

  Widget _buildPickupItem(Map<String, dynamic> p, bool isNext) {
    final wasteType = p['waste_type'] ?? 'Waste';
    final visual = ActivityItem.wasteVisual(wasteType);
    final Color typeColor = visual['color'];
    final IconData typeIcon = visual['icon'];
    final status = p['status'] ?? 'scheduled';
    final arrival = p['scheduled_arrival'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNext ? AppColors.primary.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isNext ? Border.all(color: AppColors.primary, width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: typeColor.withOpacity(0.12), shape: BoxShape.circle), child: Icon(typeIcon, color: typeColor, size: 20)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['address'] ?? 'No Address', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('${p['profiles']?['full_name'] ?? 'Resident'} • $wasteType', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
              const SizedBox(width: 8),
              if (p['latitude'] != null && p['longitude'] != null)
                IconButton(
                  icon: const Icon(Icons.directions_rounded, color: AppColors.primary, size: 24),
                  onPressed: () => _supabaseService.launchMaps(
                    (p['latitude'] as num).toDouble(),
                    (p['longitude'] as num).toDouble(),
                  ),
                  tooltip: 'Navigate',
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Action Buttons based on status
          if (status == 'assigned' || status == 'in_transit')
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Cancel Request?'),
                              content: const Text('Are you sure you want to drop this pickup?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await _supabaseService.cancelPickupAssignment(p['id'].toString());
                              if (mounted) setState(() {});
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                        icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                        label: const Text('Cancel', style: TextStyle(fontSize: 12, color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: Colors.red.withOpacity(0.4)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            await _supabaseService.markPickupArrived(p['id'].toString());
                            if (mounted) setState(() {});
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                        icon: const Icon(Icons.location_on_rounded, size: 16),
                        label: const Text("I've Arrived", style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else if (status == 'arrived')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/qr-scanner'),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Scan Resident QR', style: TextStyle(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
