import 'dart:typed_data';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // ──────────────────────────────────────────────
  //  GPS
  // ──────────────────────────────────────────────

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
          .select()
          .eq('user_id', userId)
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
  Future<List<Map<String, dynamic>>> getNearbyScheduledPickups(double lat, double lng, {double radiusKm = 15}) async {
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
  Future<void> claimPickup(String pickupId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    try {
      await _supabase.from('pickups').update({
        'collector_id': userId,
        'is_assigned': true,
      }).eq('id', pickupId);
    } catch (e) {
      debugPrint('Claim Pickup Error: $e');
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
