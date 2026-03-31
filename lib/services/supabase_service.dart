import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  /// Fetches the current user's position using device sensors
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  /// Fetches the user profile from the 'profiles' table
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

  /// Fetches rewards from the 'rewards' table
  Future<List<dynamic>> getRewards() async {
    try {
      final response = await _supabase.from('rewards').select();
      return response as List<dynamic>;
    } catch (e) {
      debugPrint('SupabaseService Rewards Error: $e');
      return [];
    }
  }

  /// Fetches pickups for the current user
  Future<List<dynamic>> getPickups() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('pickups')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return response as List<dynamic>;
    } catch (e) {
      debugPrint('SupabaseService Pickups Error: $e');
      return [];
    }
  }

  /// Schedules a new waste pickup with real GPS coordinates
  Future<void> schedulePickup({
    required String date, 
    required String wasteType, 
    required String address,
    double? latitude,
    double? longitude,
    String? photoUrl,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      // 1. Verify user is a resident
      final profile = await getProfile();
      if (profile['role'] != 'resident') {
        throw Exception('Access denied: Only households can schedule pickups.');
      }

      // 2. Find nearest online collector
      String? assignedCollectorId;
      if (latitude != null && longitude != null) {
        assignedCollectorId = await findNearestCollector(latitude, longitude);
      }

      // 3. Insert pickup record
      await _supabase.from('pickups').insert({
        'user_id': user.id,
        'date': date,
        'waste_type': wasteType,
        'address': address,
        'status': 'scheduled',
        'photo_url': photoUrl,
        'latitude': latitude,
        'longitude': longitude,
        'collector_id': assignedCollectorId,
        'is_assigned': assignedCollectorId != null,
      });
    } catch (e) {
      debugPrint('SupabaseService Schedule Error: $e');
      rethrow;
    }
  }

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

      final distance = const Distance();
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

  /// Redeems a reward and creates a fulfillment request
  Future<void> redeemReward(String rewardId, int pointsCost, String mpesaNumber) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    try {
      final profile = await getProfile();
      final currentPoints = profile['eco_points'] as int;

      if (currentPoints < pointsCost) throw Exception('Insufficient points for this reward.');

      // 1. Deduct points via Atomic Update (assuming points update correctly)
      await _supabase.from('profiles').update({
        'eco_points': currentPoints - pointsCost,
      }).eq('id', userId);

      // 2. Create Redemption Request for Admin Fulfillment
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

  /// Storage: Uploads a waste photo
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

  /// Real-time: Completes a pickup and awards points
  Future<void> completePickup(String pickupId, String userId, int pointsToAward) async {
    try {
      await _supabase.from('pickups').update({'status': 'completed'}).eq('id', pickupId);
      final profile = await _supabase.from('profiles').select('eco_points').eq('id', userId).single();
      await _supabase.from('profiles').update({'eco_points': (profile['eco_points'] as int) + pointsToAward}).eq('id', userId);
    } catch (e) {
      debugPrint('Complete Pickup Error: $e');
      rethrow;
    }
  }

  /// Real-time: Updates Collector location from device GPS
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

  /// Stream Online status for realtime sync
  Future<void> updateOnlineStatus(bool isOnline) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('profiles').update({'is_online': isOnline}).eq('id', userId);
  }

  Future<List<dynamic>> getLeaderboard() async {
    final response = await _supabase.from('profiles').select().order('eco_points', ascending: false).limit(20);
    return response as List<dynamic>;
  }

  Future<Map<String, dynamic>> getCollectorStats() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {'count': 0, 'earnings': 0};
    final response = await _supabase.from('pickups').select('points_awarded').eq('status', 'completed').eq('collector_id', userId);
    final List<dynamic> data = response;
    return {'count': data.length, 'earnings': data.fold(0, (sum, item) => sum + (item['points_awarded'] as int? ?? 0))};
  }

  Future<List<dynamic>> getPendingPickups() async {
    final response = await _supabase.from('pickups').select('*, profiles(full_name)').eq('status', 'scheduled').order('date', ascending: true);
    return response as List<dynamic>;
  }

  Future<void> signOut() async => await _supabase.auth.signOut();
}
