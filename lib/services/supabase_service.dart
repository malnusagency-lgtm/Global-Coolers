import 'dart:typed_data';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // ──────────────────────────────────────────────
  //  GPS
  // ──────────────────────────────────────────────

  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied.');
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied.');
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  // ──────────────────────────────────────────────
  //  REVERSE GEOCODE (free Nominatim / OSM)
  // ──────────────────────────────────────────────

  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&addressdetails=1',
      );
      final response = await http.get(url, headers: {'User-Agent': 'GlobalCoolers/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final parts = <String>[];
          if (addr['road'] != null) parts.add(addr['road']);
          if (addr['suburb'] != null) parts.add(addr['suburb']);
          if (addr['city'] != null) parts.add(addr['city']);
          else if (addr['town'] != null) parts.add(addr['town']);
          if (parts.isNotEmpty) return parts.join(', ');
        }
        return data['display_name'] as String?;
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
    return null;
  }

  // ──────────────────────────────────────────────
  //  PROFILES
  // ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      debugPrint('SupabaseService Profile Error: $e');
      rethrow;
    }
  }

  /// Get any user's profile by their ID (for tracking screens)
  Future<Map<String, dynamic>> getProfileById(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      debugPrint('SupabaseService GetProfileById Error: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────
  //  REWARDS
  // ──────────────────────────────────────────────

  Future<List<dynamic>> getRewards() async {
    try {
      final response = await _supabase.from('rewards').select();
      return response as List<dynamic>;
    } catch (e) {
      debugPrint('SupabaseService Rewards Error: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────
  //  PICKUPS
  // ──────────────────────────────────────────────

  Future<List<dynamic>> getPickups() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('pickups')
          .select('*, profiles(full_name)')
          .or('user_id.eq.$userId,collector_id.eq.$userId')
          .order('created_at', ascending: false);
      return response as List<dynamic>;
    } catch (e) {
      debugPrint('SupabaseService Pickups Error: $e');
      return [];
    }
  }

  /// Cancel a scheduled pickup
  Future<void> cancelPickup(String pickupId) async {
    try {
      await _supabase.from('pickups').update({
        'status': 'cancelled',
      }).eq('id', pickupId);
    } catch (e) {
      debugPrint('Cancel Pickup Error: $e');
      rethrow;
    }
  }

  /// Schedules a new waste pickup with real GPS coordinates
  Future<Map<String, dynamic>> schedulePickup({
    required String date, 
    required String wasteType, 
    required String address,
    double? latitude,
    double? longitude,
    String? photoUrl,
    bool isImmediate = false,
    double weightKg = 1.0,
    int costKes = 0,
  }) async {

    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      // 1. Verify profile exists (Retry if it was just created by trigger)
      Map<String, dynamic>? profile;
      for (int i = 0; i < 3; i++) {
        try {
          profile = await getProfile();
          break;
        } catch (_) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      if (profile == null) throw Exception('User profile not found. Please try again.');
      
      if (profile['role'] != 'resident') {
        throw Exception('Access denied: Only households can schedule pickups.');
      }

      // 2. Generate a unique QR code for verification (System -> Assignments)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (timestamp % 10000).toString().padLeft(4, '0');
      final qrCode = 'GC-$timestamp-$random';

      // 3. Insert pickup record (Broadcast as unassigned) and return data
      final response = await _supabase.from('pickups').insert({
        'user_id': user.id,
        'date': date,
        'waste_type': wasteType,
        'address': address,
        'status': 'scheduled',
        'photo_url': photoUrl,
        'latitude': latitude,
        'longitude': longitude,
        'collector_id': null,
        'is_assigned': false,
        'is_immediate': isImmediate,
        'weight_kg': weightKg,
        'cost_kes': costKes,
        'qr_code_id': qrCode, 
      }).select().single();

      return response;

    } catch (e) {
      debugPrint('SupabaseService Schedule Error: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────
  //  COLLECTOR: FIND & CLAIM NEARBY PICKUPS
  // ──────────────────────────────────────────────

  /// Finds the nearest online collector via geographic proximity
  Future<String?> findNearestCollector(double lat, double lng) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, latitude, longitude')
          .eq('role', 'collector')
          .eq('is_online', true);
      
      final List<dynamic> collectors = response;
      if (collectors.isEmpty) return null;

      final distance = Distance();
      final pickupPoint = LatLng(lat, lng);

      String? nearestId;
      double minDistance = double.infinity;

      for (var collector in collectors) {
        if (collector['latitude'] == null || collector['longitude'] == null) continue;
        
        final collectorPoint = LatLng(
          (collector['latitude'] as num).toDouble(),
          (collector['longitude'] as num).toDouble(),
        );

        final d = distance.as(LengthUnit.Meter, pickupPoint, collectorPoint);
        if (d < minDistance) {
          minDistance = d;
          nearestId = collector['id'];
        }
      }

      return nearestId;
    } catch (e) {
      debugPrint('Find Nearest Collector Error: $e');
      return null;
    }
  }

  /// Get nearby scheduled pickups (unassigned OR assigned to me) for collectors
  Future<List<Map<String, dynamic>>> getUnassignedPickupsNearby(double lat, double lng, {double radiusKm = 25.0}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('pickups')
          .select('*, profiles(full_name)')
          .eq('status', 'scheduled')
          .order('created_at', ascending: false);
      
      final List<dynamic> pickups = response;
      final distance = Distance();
      final myPoint = LatLng(lat, lng);

      final nearby = <Map<String, dynamic>>[];
      for (var p in pickups) {
        if (p['latitude'] == null || p['longitude'] == null) continue;
        
        final pickupPoint = LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        );
        final d = distance.as(LengthUnit.Kilometer, myPoint, pickupPoint);
        
        if (d <= radiusKm) {
          final map = Map<String, dynamic>.from(p as Map);
          map['distance_km'] = d;
          // Show if this is unassigned OR assigned to me
          final isUnassigned = map['collector_id'] == null || map['is_assigned'] != true;
          final isAssignedToMe = map['collector_id'] == userId;
          if (isUnassigned || isAssignedToMe) {
            map['is_mine'] = isAssignedToMe;
            nearby.add(map);
          }
        }
      }

      // Sort by distance
      nearby.sort((a, b) => (a['distance_km'] as double).compareTo(b['distance_km'] as double));
      return nearby;
    } catch (e) {
      debugPrint('Get Nearby Pickups Error: $e');
      return [];
    }
  }

  /// Collector claims an unassigned pickup
  Future<void> claimPickup(String pickupId, {String? initialStatus, String? scheduledArrival}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    try {
      final isImmediate = (initialStatus == 'in_transit');

      await _supabase.rpc(
        'collector_claim_pickup',
        params: {
          'p_pickup_id': pickupId,
          'p_is_immediate': isImmediate,
          'p_scheduled_arrival': scheduledArrival,
        },
      );
    } catch (e) {
      debugPrint('Claim Pickup Error: $e');
      rethrow;
    }
  }

  /// Collector cancels an accepted assignment (returns it to 'scheduled' status)
  Future<void> cancelPickupAssignment(String pickupId) async {
    try {
      await _supabase.from('pickups').update({
        'collector_id': null,
        'is_assigned': false,
        'status': 'scheduled',
        'scheduled_arrival': null,
      }).eq('id', pickupId);
    } catch (e) {
      debugPrint('Cancel Assignment Error: $e');
      rethrow;
    }
  }

  /// Collector reschedules an assigned pickup
  Future<void> reschedulePickupAssignment(String pickupId, String newTime) async {
    try {
      await _supabase.from('pickups').update({
        'scheduled_arrival': newTime,
        'status': 'accepted', // Reset to accepted if it was in_transit
      }).eq('id', pickupId);
    } catch (e) {
      debugPrint('Reschedule Assignment Error: $e');
      rethrow;
    }
  }

  /// Collector marks that they have arrived at the resident's location
  Future<void> markPickupArrived(String pickupId) async {
    try {
      await _supabase.from('pickups').update({
        'status': 'arrived',
      }).eq('id', pickupId);
    } catch (e) {
      debugPrint('Mark Arrived Error: $e');
      rethrow;
    }
  }

  /// Generic update for status changes
  Future<void> updatePickupStatus(String pickupId, String status) async {
    try {
      await _supabase.from('pickups').update({
        'status': status,
      }).eq('id', pickupId);
    } catch (e) {
      debugPrint('Update Status Error: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────
  //  ADDRESS MANAGEMENT (SharedPreferences)
  // ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUserAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_addresses');
    if (raw == null) return [];
    final List<dynamic> decoded = json.decode(raw);
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> saveUserAddress(Map<String, dynamic> address) async {
    final addresses = await getUserAddresses();
    // Generate a simple ID
    address['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    // If first address, make it default
    if (addresses.isEmpty) address['is_default'] = true;
    addresses.add(address);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_addresses', json.encode(addresses));
  }

  Future<void> updateUserAddress(String addressId, Map<String, dynamic> updated) async {
    final addresses = await getUserAddresses();
    final idx = addresses.indexWhere((a) => a['id'] == addressId);
    if (idx >= 0) {
      updated['id'] = addressId;
      updated['is_default'] = addresses[idx]['is_default'] ?? false;
      addresses[idx] = updated;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_addresses', json.encode(addresses));
    }
  }

  Future<void> deleteUserAddress(String addressId) async {
    final addresses = await getUserAddresses();
    addresses.removeWhere((a) => a['id'] == addressId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_addresses', json.encode(addresses));
  }

  Future<void> setDefaultAddress(String addressId) async {
    final addresses = await getUserAddresses();
    for (var a in addresses) {
      a['is_default'] = (a['id'] == addressId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_addresses', json.encode(addresses));
  }

  Future<Map<String, dynamic>?> getDefaultAddress() async {
    final addresses = await getUserAddresses();
    try {
      return addresses.firstWhere((a) => a['is_default'] == true);
    } catch (_) {
      return addresses.isNotEmpty ? addresses.first : null;
    }
  }

  // ──────────────────────────────────────────────
  //  NOTIFICATIONS
  // ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Get Notifications Error: $e');
      return [];
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await _supabase.from('notifications').update({'is_read': true}).eq('id', id);
    } catch (e) {
      debugPrint('Mark Read Error: $e');
    }
  }

  Future<void> markAllNotificationsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('notifications').update({'is_read': true}).eq('user_id', userId);
    } catch (e) {
      debugPrint('Mark All Read Error: $e');
    }
  }

  // ──────────────────────────────────────────────
  //  REDEMPTION
  // ──────────────────────────────────────────────

  Future<void> redeemReward(String rewardId, int pointsCost, String mpesaNumber) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    try {
      final profile = await getProfile();
      final currentPoints = profile['eco_points'] as int;

      if (currentPoints < pointsCost) throw Exception('Insufficient points for this reward.');

      await _supabase.from('profiles').update({
        'eco_points': currentPoints - pointsCost,
      }).eq('id', userId);

      await _supabase.from('redemptions').insert({
        'user_id': userId,
        'reward_id': rewardId,
        'points_spent': pointsCost,
        'mpesa_number': mpesaNumber,
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('Redemption Error: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────
  //  STORAGE
  // ──────────────────────────────────────────────

  Future<String?> uploadWastePhoto(Uint8List fileBytes, String extension) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = 'waste-photos/$fileName';

    try {
      await _supabase.storage.from('waste-photos').uploadBinary(path, fileBytes);
      return _supabase.storage.from('waste-photos').getPublicUrl(path);
    } catch (e) {
      debugPrint('Upload Error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────
  //  PICKUP COMPLETION & TRACKING
  // ──────────────────────────────────────────────

  /// Mandatory QR verification to complete a pickup and award rewards
  Future<void> completePickup({
    required String pickupId, 
    required String qrCode,
    double? actualWeightKg,
  }) async {
    try {
      final weight = actualWeightKg ?? 1.0;

      // Let Postgres handle the verification and point generation securely!
      await _supabase.rpc(
        'collector_complete_pickup',
        params: {
          'p_pickup_id': pickupId,
          'p_qr_code': qrCode,
          'p_actual_weight': weight,
        },
      );
    } catch (e) {
      debugPrint('Complete Pickup Error: $e');
      rethrow;
    }
  }

  Future<void> updateLocationFromGps() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final pos = await getCurrentPosition();
    if (pos == null) return;

    try {
      await _supabase.from('profiles').update({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      }).eq('id', userId);
    } catch (e) {
      debugPrint('Update Location Error: $e');
    }
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('profiles').update({'is_online': isOnline}).eq('id', userId);
  }

  Future<bool> isNearLocation(double targetLat, double targetLng, {double radiusMeters = 200}) async {
    final pos = await getCurrentPosition();
    if (pos == null) return false;
    
    final distance = const Distance().as(LengthUnit.Meter, 
      LatLng(pos.latitude, pos.longitude), 
      LatLng(targetLat, targetLng)
    );
    
    return distance <= radiusMeters;
  }

  Future<Map<String, dynamic>> verifyPickupByQr(String code) async {
    try {
      final response = await _supabase
          .from('pickups')
          .select('*, profiles(full_name)')
          .eq('qr_code_id', code)
          .single();
      return response;
    } catch (e) {
      debugPrint('Verify Pickup QR Error: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> streamLocation(String collectorId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', collectorId)
        .map((maps) => maps.map((m) => m).toList());
  }

  Future<void> updateLocation(double lat, double lng) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('profiles').update({
      'latitude': lat,
      'longitude': lng,
    }).eq('id', userId);
  }

  Future<List<dynamic>> getLeaderboard({String sortBy = 'eco_points', bool isNeighborhood = false}) async {
    if (isNeighborhood) {
      return getNeighborhoodLeaderboard(sortBy: sortBy);
    }
    final response = await _supabase.from('profiles').select().order(sortBy, ascending: false).limit(20);
    return response as List<dynamic>;
  }

  Future<Map<String, dynamic>> getCollectorStats() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {'count': 0, 'earnings': 0};
    
    try {
      // 1. Get count of completed pickups
      final countResponse = await _supabase
          .from('pickups')
          .select('id')
          .eq('status', 'completed')
          .eq('collector_id', userId);
      
      // 2. Get real eco_points from profile as "earnings"
      final profile = await getProfile();
      
      return {
        'count': (countResponse as List).length,
        'earnings': profile['eco_points'] ?? 0
      };
    } catch (e) {
      debugPrint('Get Collector Stats Error: $e');
      return {'count': 0, 'earnings': 0};
    }
  }

  /// Mark all completed pickups as hidden for the user
  Future<void> clearUserHistory() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // We'll mark them as 'hidden' or similar if the column exists, 
      // or we can use a local 'hidden_pickups' filter if we don't want to change schema.
      // For now, let's assume we can update a 'is_hidden' field or just return unhidden ones.
      // If schema change isn't allowed, we'd use local storage.
      // Assuming 'is_hidden' column might not exist, we will use a more robust way:
      // We will update the status to 'archived' which won't show in normal history.
      
      await _supabase
          .from('pickups')
          .update({'status': 'archived'}) 
          .eq('user_id', userId)
          .eq('status', 'completed');
          
      // Also for collector if they are the one clearing
       await _supabase
          .from('pickups')
          .update({'status': 'archived'}) 
          .eq('collector_id', userId)
          .eq('status', 'completed');
          
    } catch (e) {
      debugPrint('Clear History Error: $e');
      // Fallback: if 'archived' status isn't supported or errors, we'll ignore for now
    }
  }

  Future<List<dynamic>> getPendingPickups() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final response = await _supabase.from('pickups').select('*, profiles(full_name)').eq('collector_id', userId).neq('status', 'completed').order('date', ascending: true);
    return response as List<dynamic>;
  }


  // ──────────────────────────────────────────────
  //  COLLECTOR ACTIONS (ACCEPT / ROUTE)
  // ──────────────────────────────────────────────

  Future<void> acceptPickup(String pickupId, {bool immediate = true, String? arrivalTime}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final updates = <String, dynamic>{
      'collector_id': userId,
      'status': immediate ? 'in_transit' : 'accepted',
    };
    
    if (arrivalTime != null) {
      updates['scheduled_arrival'] = arrivalTime;
    }

    try {
      // Use filter to prevent race conditions
      final response = await _supabase
          .from('pickups')
          .update(updates)
          .eq('id', pickupId)
          .filter('collector_id', 'is', null)
          .select();
          
      if (response.isEmpty) {
        throw Exception('This pickup has already been accepted by another collector.');
      }
    } catch (e) {
      debugPrint('Accept Pickup Error: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> streamUnassignedPickups() {
    return _supabase
        .from('pickups')
        .stream(primaryKey: ['id'])
        .eq('status', 'scheduled')
        .map((list) => list.where((p) => p['collector_id'] == null).toList());
  }

  /// Streams the resident's latest active pickup with collector info for the home screen tracker
  Stream<Map<String, dynamic>?> streamActivePickupForResident() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _supabase
        .from('pickups')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((list) {
          final activeStatuses = ['scheduled', 'accepted', 'in_transit', 'arrived'];
          final active = list.where((p) => activeStatuses.contains(p['status'])).toList();
          if (active.isEmpty) return null;
          // Most recent first
          active.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
          return active.first as Map<String, dynamic>;
        });
  }

  Future<void> launchMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> signOut() async => await _supabase.auth.signOut();

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: kIsWeb ? null : 'io.supabase.flutter://reset-callback/',
    );
  }

  Stream<Map<String, dynamic>> streamPickupStatus(String pickupId) {
    return _supabase
        .from('pickups')
        .stream(primaryKey: ['id'])
        .eq('id', pickupId)
        .map((list) => list.first);
  }

  // ──────────────────────────────────────────────
  //  REWARDS
  // ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRewards() async {
    final response = await _supabase
        .from('rewards')
        .select()
        .eq('is_active', true)
        .order('cost', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }


  // ──────────────────────────────────────────────
  //  RATINGS & REVIEWS
  // ──────────────────────────────────────────────

  Future<void> submitRating({
    required String pickupId,
    required int rating,
    String comment = '',
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    try {
      // Get pickup to find the other party
      final pickup = await _supabase.from('pickups').select().eq('id', pickupId).single();
      final revieweeId = pickup['collector_id'] ?? pickup['user_id'];

      await _supabase.from('reviews').insert({
        'pickup_id': pickupId,
        'reviewer_id': userId,
        'reviewee_id': revieweeId,
        'rating': rating,
        'comment': comment,
      });

      // Also store rating on the pickup for quick access
      await _supabase.from('pickups').update({'rating': rating}).eq('id', pickupId);
    } catch (e) {
      debugPrint('Submit Rating Error: $e');
      rethrow;
    }
  }

  Future<double> getAverageRating(String userId) async {
    try {
      final reviews = await _supabase.from('reviews').select('rating').eq('reviewee_id', userId);
      if ((reviews as List).isEmpty) return 0;
      final total = reviews.fold<int>(0, (sum, r) => sum + (r['rating'] as int));
      return total / reviews.length;
    } catch (e) {
      return 0;
    }
  }

  // ──────────────────────────────────────────────
  //  COLLECTOR EARNINGS (DETAILED)
  // ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getCollectorEarningsDetailed() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {'completed': [], 'total_earnings': 0, 'total_points': 0};

    try {
      final completed = await _supabase
          .from('pickups')
          .select()
          .eq('collector_id', userId)
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      int totalEarnings = 0;
      int totalPoints = 0;
      for (var p in completed) {
        totalEarnings += ((p['cost_kes'] ?? 0) as num).toInt();
        totalPoints += ((p['points_awarded'] ?? 0) as num).toInt();
      }

      return {
        'completed': completed,
        'total_earnings': totalEarnings,
        'total_points': totalPoints,
      };
    } catch (e) {
      debugPrint('Collector Earnings Error: $e');
      return {'completed': [], 'total_earnings': 0, 'total_points': 0};
    }
  }

  // ──────────────────────────────────────────────
  //  CHALLENGES (JOIN / TRACK)
  // ──────────────────────────────────────────────

  Future<void> joinChallenge(String challengeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    try {
      await _supabase.from('challenge_participants').insert({
        'user_id': userId,
        'challenge_id': challengeId,
        'joined_at': DateTime.now().toIso8601String(),
        'progress': 0,
      });
    } catch (e) {
      debugPrint('Join Challenge Error: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────
  //  CONSOLIDATED API METHODS (From ApiService)
  // ──────────────────────────────────────────────

  Future<List<dynamic>> getAllChallenges() async {
    try {
      final response = await _supabase
          .from('challenges')
          .select('*')
          .order('ends_at', ascending: true);
      return response as List<dynamic>;
    } catch (e) {
      debugPrint('Get All Challenges Error: $e');
      return [];
    }
  }

  Future<void> submitReport({
    required String issueType,
    required String location,
    required String description,
    String? photoUrl,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    try {
      await _supabase.from('reports').insert({
        'user_id': userId,
        'issue_type': issueType,
        'location': location,
        'description': description,
        'photo_url': photoUrl,
        'status': 'pending'
      });
    } catch (e) {
      debugPrint('Submit Report Error: $e');
      rethrow;
    }
  }

  Future<void> updateGenericProfile({
    String? fullName,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (address != null) updates['address'] = address;
    if (latitude != null) updates['latitude'] = latitude;
    if (longitude != null) updates['longitude'] = longitude;

    if (updates.isEmpty) return;

    try {
      await _supabase.from('profiles').update(updates).eq('id', userId);
    } catch (e) {
      debugPrint('Update Generic Profile Error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getUserChallenges() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('challenge_participants')
          .select('*, challenges(*)')
          .eq('user_id', userId);
      return response as List<dynamic>;
    } catch (e) {
      debugPrint('Get User Challenges Error: $e');
      return [];
    }
  }

  Future<List<String>> getJoinedChallengeIds() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('challenge_participants')
          .select('challenge_id')
          .eq('user_id', userId);
      return (response as List).map<String>((r) => r['challenge_id'].toString()).toList();
    } catch (e) {
      return [];
    }
  }

  // ──────────────────────────────────────────────
  //  WASTE BREAKDOWN (REAL DATA)
  // ──────────────────────────────────────────────

  Future<Map<String, double>> getWasteBreakdown() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};

    try {
      final pickups = await _supabase
          .from('pickups')
          .select('waste_type, weight_kg')
          .eq('user_id', userId)
          .eq('status', 'completed');

      final breakdown = <String, double>{};
      for (var p in pickups) {
        final type = p['waste_type'] ?? 'Other';
        final weight = ((p['weight_kg'] ?? 1.0) as num).toDouble();
        breakdown[type] = (breakdown[type] ?? 0) + weight;
      }
      return breakdown;
    } catch (e) {
      debugPrint('Waste Breakdown Error: $e');
      return {};
    }
  }

  // ──────────────────────────────────────────────
  //  REFERRAL SYSTEM
  // ──────────────────────────────────────────────

  Future<String> getReferralCode() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return '';

    try {
      final profile = await getProfile();
      if (profile['referral_code'] != null) return profile['referral_code'];

      // Generate referral code
      final code = 'GC-${userId.substring(0, 6).toUpperCase()}';
      await _supabase.from('profiles').update({'referral_code': code}).eq('id', userId);
      return code;
    } catch (e) {
      return 'GC-${userId.substring(0, 6).toUpperCase()}';
    }
  }

  Future<int> getReferralCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final code = await getReferralCode();
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('referred_by', code);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  // ──────────────────────────────────────────────
  //  PHOTO VERIFICATION (Collector Side)
  // ──────────────────────────────────────────────

  Future<void> submitVerificationPhoto(String pickupId, String photoUrl) async {
    try {
      await _supabase.from('pickups').update({
        'verification_photo_url': photoUrl,
      }).eq('id', pickupId);
    } catch (e) {
      debugPrint('Verification Photo Error: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────
  //  STREAK TRACKING
  // ──────────────────────────────────────────────

  Future<int> getUserStreak() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final pickups = await _supabase
          .from('pickups')
          .select('created_at')
          .eq('user_id', userId)
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      if ((pickups as List).isEmpty) return 0;

      // Count consecutive weeks with a pickup
      int streak = 0;
      DateTime checkDate = DateTime.now();

      for (int week = 0; week < 52; week++) {
        final weekStart = checkDate.subtract(Duration(days: checkDate.weekday + (week * 7)));
        final weekEnd = weekStart.add(const Duration(days: 7));

        final hasPickup = pickups.any((p) {
          try {
            final d = DateTime.parse(p['created_at']);
            return d.isAfter(weekStart) && d.isBefore(weekEnd);
          } catch (_) {
            return false;
          }
        });

        if (hasPickup) {
          streak++;
        } else if (week > 0) {
          break; // Streak broken
        }
      }

      return streak;
    } catch (e) {
      debugPrint('Get Streak Error: $e');
      return 0;
    }
  }

  // ──────────────────────────────────────────────
  //  NEIGHBORHOOD LEADERBOARD
  // ──────────────────────────────────────────────

  Future<List<dynamic>> getNeighborhoodLeaderboard({String sortBy = 'eco_points'}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final profile = await getProfile();
      final myAddress = profile['address'] as String?;
      if (myAddress == null) return [];

      // Extract area keyword from address
      final parts = myAddress.split(',');
      final area = parts.length > 1 ? parts[1].trim() : parts[0].trim();

      final response = await _supabase
          .from('profiles')
          .select('id, full_name, eco_points, co2_saved, address')
          .ilike('address', '%$area%')
          .order(sortBy, ascending: false)
          .limit(20);

      return response as List<dynamic>;
    } catch (e) {
      debugPrint('Neighborhood Leaderboard Error: $e');
      return [];
    }
  }
}

