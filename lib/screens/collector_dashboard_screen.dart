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

      // 1. Capacity Check: Max 5 active tasks
      final activeTasks = await _supabaseService.getPendingPickups();
      if (activeTasks.length >= 5) return;

      // 2. Proximity & Declined Check
      final distance = const Distance();
      final myPoint = LatLng(pos.latitude, pos.longitude);

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
        _declinedPickups.add(newRequest['id'].toString()); // Prevent this specific pickup from triggering the modal again
        _showNewRequestOverlay(newRequest);
      }
    });
  }

  void _showNewRequestOverlay(Map<String, dynamic> pickup) {
    if (!mounted) return;
    TimeOfDay? selectedTime;
    
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'New Request',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: curve,
            child: StatefulBuilder(
              builder: (context, setModalState) => AlertDialog(
                contentPadding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                content: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 40, spreadRadius: 10),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Gradient
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 32),
                            ),
                            const SizedBox(height: 12),
                            const Text('NEW PICKUP!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          ],
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Text(
                              'A resident near you has requested a ${pickup['waste_type']} collection.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 20),
                            
                            // Info Row
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.background.withOpacity(0.5),
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
                                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                       maxLines: 2,
                                       overflow: TextOverflow.ellipsis,
                                     ),
                                   ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // PREMIUM PICKER SECTION
                            const Text('WHEN WILL YOU ARRIVE?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _timeChip(
                                  label: 'ASAP',
                                  isSelected: selectedTime == null,
                                  onTap: () => setModalState(() => selectedTime = null),
                                ),
                                const SizedBox(width: 8),
                                _timeChip(
                                  label: selectedTime != null ? selectedTime!.format(context) : 'LATER',
                                  isSelected: selectedTime != null,
                                  onTap: () async {
                                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                    if (time != null) setModalState(() => selectedTime = time);
                                  },
                                  showIcon: true,
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // ACTION BUTTONS
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    ),
                                    child: const Text('Decline', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await _handleClaim(pickup, arrivalTime: selectedTime?.format(context));
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      elevation: 8,
                                      shadowColor: AppColors.primary.withOpacity(0.4),
                                    ),
                                    child: Text(selectedTime == null ? 'Start Now' : 'Accept Task', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) _isShowingRequest = false;
    });
  }

  Widget _timeChip({required String label, required bool isSelected, required VoidCallback onTap, bool showIcon = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.3), width: 2),
            boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showIcon) Icon(Icons.schedule_rounded, size: 16, color: isSelected ? Colors.white : AppColors.primary),
              if (showIcon) const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleClaim(Map<String, dynamic> pickup, {String? arrivalTime}) async {
    try {
      final pickupId = pickup['id'];
      if (pickupId == null) throw Exception('Unable to find pickup ID');
      
      await _supabaseService.claimPickup(
        pickupId.toString(),
        immediate: arrivalTime == null,
        arrivalTime: arrivalTime,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pickup claimed! 🎉 It\'s now in your tasks.'), backgroundColor: AppColors.success),
        );
        // Refresh both lists
        _loadNearbyPickups(); 
        setState(() {}); // Rebuild FutureBuilder for tasks
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
        final stats = snapshot.data ?? {
          'total_collections': 0,
          'total_earnings': 0,
        };
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildStatCard('Collections', '${stats['total_collections'] ?? 0}', Icons.local_shipping_rounded, AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Earnings (KES)', '${stats['total_earnings'] ?? 0}', Icons.account_balance_wallet_rounded, AppColors.amber)),
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
              Text('${pickup['waste_type']} • ${pickup['weight_kg']}kg', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                Text('${p['profiles']?['full_name'] ?? 'Resident'} • ${p['waste_type']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (p['scheduled_arrival'] != null)
                   Padding(
                     padding: const EdgeInsets.only(top: 4),
                     child: Text('Scheduled for: ${p['scheduled_arrival']}', style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                   ),
              ])),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(onPressed: () => _supabaseService.launchMaps(p['latitude'], p['longitude']), icon: const Icon(Icons.directions_rounded, color: AppColors.primary)),
              IconButton(onPressed: () => Navigator.pushNamed(context, '/chat', arguments: {'pickupId': p['id'], 'recipientName': p['profiles']?['full_name']}), icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.teal)),
              const Spacer(),
              if (status == 'accepted' || status == 'in_transit' || status == 'arrived') ...[
                TextButton(
                  onPressed: () => _showSchedulePicker(p, isReschedule: true),
                  child: const Text('Reschedule', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (status == 'accepted' || status == 'in_transit' || status == 'arrived')
                TextButton(
                  onPressed: () => _cancelAssignment(p['id']),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.error, fontSize: 13)),
                ),
              const Spacer(),
              if (status == 'accepted' || status == 'in_transit')
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _checkArrival(p), 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success, 
                      foregroundColor: Colors.white,
                      elevation: 2,
                    ), 
                    child: const Text('I\'ve Arrived', maxLines: 1, overflow: TextOverflow.ellipsis)
                  )
                )
              else if (status == 'arrived')
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/qr-scanner', arguments: {'pickupId': p['id'].toString()}), 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal, 
                      foregroundColor: Colors.white,
                      elevation: 4,
                    ), 
                    child: const Text('Scan QR to Earn', maxLines: 1, overflow: TextOverflow.ellipsis)
                  )
                )
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
        final pickupId = id;
        if (pickupId == null) throw Exception('Unable to find pickup ID');
        
        await _supabaseService.collectorCancelPickup(pickupId.toString());
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

  void _showSchedulePicker(Map<String, dynamic> pickup, {bool isReschedule = false}) async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time != null) {
      if (isReschedule) {
        await _supabaseService.reschedulePickupAssignment(pickup['id'].toString(), time.format(context));
        setState(() {});
      } else {
        _handleClaim(pickup, arrivalTime: time.format(context));
      }
    }
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
    
    // ✅ Direct and smooth transition
    await _updateStatus(p['id'], 'arrived');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arrived! Opening scanner... 📷'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 1),
        ),
      );
      
      // Delay slightly for the snackbar to be seen, then navigate
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushNamed(context, '/qr-scanner', arguments: {'pickupId': p['id'].toString()});
        }
      });
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
