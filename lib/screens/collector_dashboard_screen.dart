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
  late TabController _tabController;
  
  // Real-time Request Stream
  StreamSubscription? _poolSubscription;
  List<dynamic> _availablePool = [];
  bool _isLoadingPool = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _startLocationUpdates();
    _initPoolStream();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _poolSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _initPoolStream() {
    _poolSubscription = _supabaseService.streamUnassignedPickups().listen((pickups) {
      if (mounted) {
        setState(() {
          _availablePool = pickups;
          _isLoadingPool = false;
        });
      }
    });
  }

  void _startLocationUpdates() {
    // Update GPS every 15 seconds when online (for real-time tracking)
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      final userProvider = context.read<UserProvider>();
      if (userProvider.isOnline) {
        _supabaseService.updateLocationFromGps();
      }
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
          const SnackBar(content: Text('Pickup claimed! 🎉 Switching to My Tasks.'), backgroundColor: AppColors.success),
        );
        _tabController.animateTo(1); // Switch to My Tasks
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Claim failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Collector Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          _buildOnlineToggle(userProvider),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Available Pool'),
            Tab(text: 'My Tasks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPoolTab(userProvider),
          _buildTasksTab(userProvider),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        role: UserRole.collector,
        onTap: (index) {
          if (index == 2) {
             Navigator.pushNamed(context, '/profile');
          } else {
            setState(() => _currentNavIndex = index);
          }
        },
      ),
    );
  }

  Widget _buildPoolTab(UserProvider userProvider) {
    if (!userProvider.isOnline) {
      return _buildOfflineState();
    }

    if (_isLoadingPool) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_availablePool.isEmpty) {
      return _buildEmptyState(
        Icons.radar_rounded,
        'Scanning for pickups...',
        'New requests will appear here in real-time as they are broadcasted by residents.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _availablePool.length,
      itemBuilder: (context, index) {
        final pickup = _availablePool[index];
        return _buildPoolCard(pickup);
      },
    );
  }

  Widget _buildTasksTab(UserProvider userProvider) {
    if (!userProvider.isOnline) {
      return _buildOfflineState();
    }

    return FutureBuilder<List<dynamic>>(
      future: _supabaseService.getPendingPickups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          return _buildEmptyState(
            Icons.assignment_rounded,
            'No Active Tasks',
            'Claim a pickup from the Pool to start earning.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            return _buildTaskCard(tasks[index]);
          },
        );
      },
    );
  }

  Widget _buildPoolCard(Map<String, dynamic> pickup) {
    final type = pickup['waste_type'] ?? 'Waste';
    final visual = ActivityItem.wasteVisual(type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: (visual['color'] as Color).withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(visual['icon'] as IconData, color: visual['color'] as Color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pickup['address'] ?? 'Nearby Pickup', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('$type • ${pickup['weight_kg']}kg', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              if (pickup['is_immediate'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Text('URGENT', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showSchedulePicker(pickup),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Schedule'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleClaim(pickup),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Claim Now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final status = task['status'] as String? ?? 'accepted';
    final type = task['waste_type'] ?? 'Waste';
    final visual = ActivityItem.wasteVisual(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: status == 'in_transit' ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: (visual['color'] as Color).withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(visual['icon'] as IconData, color: visual['color'] as Color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task['address'] ?? 'Task', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${task['profiles']?['full_name'] ?? 'Resident'} • $type', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              IconButton(
                onPressed: () => _supabaseService.launchMaps(task['latitude'], task['longitude']),
                icon: const Icon(Icons.directions_rounded, color: AppColors.primary),
                tooltip: 'Navigate',
              ),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/chat', arguments: {'pickupId': task['id'], 'recipientName': task['profiles']?['full_name']}),
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.teal),
                tooltip: 'Chat',
              ),
              const Spacer(),
              if (status == 'accepted')
                ElevatedButton(
                  onPressed: () => _updateTaskStatus(task['id'], 'in_transit'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Start Trip'),
                )
              else if (status == 'in_transit')
                 ElevatedButton(
                  onPressed: () => _checkArrivalAndScan(task),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Verify & Complete'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSchedulePicker(Map<String, dynamic> pickup) async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time != null) {
      _handleClaim(pickup, arrivalTime: time.format(context));
    }
  }

  Future<void> _updateTaskStatus(dynamic pickupId, String status) async {
    try {
      await _supabaseService.updatePickupStatus(pickupId.toString(), status);
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  Future<void> _checkArrivalAndScan(Map<String, dynamic> task) async {
    final lat = (task['latitude'] as num?)?.toDouble();
    final lng = (task['longitude'] as num?)?.toDouble();
    
    if (lat != null && lng != null) {
      final arrived = await _supabaseService.isNearLocation(lat, lng);
      if (!arrived) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be within 200m of the resident to complete verification.'), backgroundColor: AppColors.error),
          );
        }
        return;
      }
    }
    
    if (mounted) {
      Navigator.pushNamed(context, '/qr-scanner', arguments: {'pickupId': task['id'].toString()});
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    String text = status.toUpperCase();
    
    if (status == 'in_transit') { color = AppColors.primary; text = 'ON THE WAY'; }
    if (status == 'arrived') { color = AppColors.success; text = 'ARRIVED'; }
    if (status == 'accepted') { color = AppColors.teal; text = 'ACCEPTED'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade200),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineState() {
    return _buildEmptyState(
      Icons.cloud_off_rounded,
      'You are Offline',
      'Toggle the switch in the top right to go online and start receiving collection requests.',
    );
  }

  Widget _buildOnlineToggle(UserProvider provider) {
    return Row(
      children: [
        Text(
          provider.isOnline ? 'ONLINE' : 'OFFLINE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: provider.isOnline ? AppColors.success : Colors.grey,
          ),
        ),
        const SizedBox(width: 4),
        Switch(
          value: provider.isOnline,
          onChanged: (val) async {
            try {
              await provider.toggleOnlineStatus();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          },
          activeColor: AppColors.success,
        ),
      ],
    );
  }
}
