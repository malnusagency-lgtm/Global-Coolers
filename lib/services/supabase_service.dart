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

  // ========================= AUTH =========================

  User? get currentUser => _supabase.auth.currentUser;

  Future<void> signOut() async => await _supabase.auth.signOut();

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: kIsWeb ? null : 'io.supabase.flutter://reset-callback/',
    );
  }

  // ========================= PROFILE =========================

  Future<Map<String, dynamic>> getProfile() async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    return await _supabase.from('profiles').select().eq('id', userId).single();
  }

  Future<Map<String, dynamic>> getProfileById(String userId) async {
    return await _supabase.from('profiles').select().eq('id', userId).single();
  }

  /// Unified Profile Update with named parameters to match UI expectations.
  Future<void> updateGenericProfile({
    String? fullName,
    String? phone,
    String? address,
    Map<String, dynamic>? extraUpdates,
  }) async {
    await _supabase.rpc('update_user_profile', params: {
      'p_full_name': fullName,
      'p_phone': phone,
      'p_address': address,
    });
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    await _supabase.rpc('update_user_profile', params: {'p_is_online': isOnline});
  }

  // ========================= GPS & GEO =========================

  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> updateLocation(double lat, double lng) async {
    await _supabase.rpc('update_user_profile', params: {
      'p_latitude': lat,
      'p_longitude': lng,
    });
  }

  Future<void> updateLocationFromGps() async {
    final pos = await getCurrentPosition();
    if (pos != null) await updateLocation(pos.latitude, pos.longitude);
  }

  Stream<List<Map<String, dynamic>>> streamLocation(String userId) {
    return _supabase.from('profiles').stream(primaryKey: ['id']).eq('id', userId);
  }

  Future<bool> isNearLocation(double targetLat, double targetLng, {double thresholdMeters = 100}) async {
    final pos = await getCurrentPosition();
    if (pos == null) return false;
    final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, targetLat, targetLng);
    return dist <= thresholdMeters;
  }

  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng');
      final res = await http.get(url, headers: {'User-Agent': 'GlobalCoolers/1.0'});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['display_name'];
      }
    } catch (_) {}
    return null;
  }

  // ========================= ADDRESSES =========================

  Future<List<Map<String, dynamic>>> getUserAddresses() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final res = await _supabase.from('addresses').select().eq('user_id', userId).order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>?> getDefaultAddress() async {
    final addresses = await getUserAddresses();
    if (addresses.isEmpty) return null;
    return addresses.firstWhere((a) => a['is_default'] == true, orElse: () => addresses.first);
  }

  Future<void> saveUserAddress(Map<String, dynamic> addressData) async {
    await _supabase.rpc('add_user_address', params: {
      'p_label': addressData['label'] ?? 'Home',
      'p_address': addressData['address'],
      'p_lat': addressData['latitude'],
      'p_lng': addressData['longitude'],
      'p_is_default': addressData['is_default'] ?? false,
    });
  }

  Future<void> updateUserAddress(String id, Map<String, dynamic> data) async {
    await _supabase.rpc('update_user_address', params: {
      'p_address_id': id,
      'p_label': data['label'],
      'p_address': data['address'],
      'p_lat': data['latitude'],
      'p_lng': data['longitude'],
    });
  }

  Future<void> deleteUserAddress(String id) async {
    await _supabase.rpc('delete_user_address', params: {'p_address_id': id});
  }

  Future<void> setDefaultAddress(String id) async {
    await _supabase.rpc('set_default_address', params: {'p_address_id': id});
  }

  // ========================= PICKUPS =========================

  Future<List<Map<String, dynamic>>> getPickups() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final res = await _supabase.from('pickups')
        .select()
        .or('user_id.eq.$userId,collector_id.eq.$userId')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Stream<List<Map<String, dynamic>>> streamResidentActivePickups() {
    final userId = currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _supabase.from('pickups').stream(primaryKey: ['id']).eq('user_id', userId).asyncMap((list) async {
      const activeStatuses = ['scheduled', 'accepted', 'in_transit', 'arrived'];
      final active = list.where((p) => activeStatuses.contains(p['status'])).toList();
      active.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

      for (var pickup in active) {
        if (pickup['collector_id'] != null) {
          try {
            final collector = await getProfileById(pickup['collector_id']);
            pickup['collector_name'] = collector['full_name'];
          } catch (_) {
            pickup['collector_name'] = 'A Collector';
          }
        }
      }
      return active.cast<Map<String, dynamic>>();
    });
  }

  Stream<Map<String, dynamic>?> streamActivePickupForResident() {
    return streamResidentActivePickups().map((list) => list.isNotEmpty ? list.first : null);
  }

  Stream<Map<String, dynamic>> streamPickupStatus(String pickupId) {
    return _supabase.from('pickups').stream(primaryKey: ['id']).eq('id', pickupId).map((list) => list.first);
  }

  Stream<List<Map<String, dynamic>>> streamUnassignedPickups() {
    return _supabase.from('pickups').stream(primaryKey: ['id']).eq('status', 'scheduled').map((list) => list.where((p) => p['collector_id'] == null).toList());
  }

  Future<List<Map<String, dynamic>>> getUnassignedPickupsNearby(double lat, double lng, {double radiusKm = 10.0}) async {
    final res = await _supabase.rpc('get_nearby_pickups', params: {
      'p_lat': lat,
      'p_lng': lng,
      'p_radius_km': radiusKm,
    });
    return List<Map<String, dynamic>>.from(res);
  }

  Stream<List<Map<String, dynamic>>> streamPendingPickups() {
    final userId = currentUser?.id;
    if (userId == null) return const Stream.empty();
    
    return _supabase.from('pickups')
        .stream(primaryKey: ['id'])
        .eq('collector_id', userId)
        .asyncMap((list) async {
          final active = list.where((p) => p['status'] != 'completed' && p['status'] != 'cancelled' && p['status'] != 'archived').toList();
          
          for (var pickup in active) {
             try {
                final resident = await getProfileById(pickup['user_id']);
                pickup['profiles'] = {'full_name': resident['full_name']};
             } catch (_) {
                pickup['profiles'] = {'full_name': 'Resident'};
             }
          }
          return active;
        });
  }

  Future<List<Map<String, dynamic>>> getPendingPickups() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    
    final res = await _supabase.from('pickups')
        .select()
        .eq('collector_id', userId)
        .not('status', 'in', '("completed", "cancelled", "archived")');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<String?> schedulePickup({required String wasteType, required String address, required double latitude, required double longitude, required String date, required String qrCodeId}) async {
    final res = await _supabase.rpc('resident_schedule_pickup', params: {
      'p_waste_type': wasteType,
      'p_address': address,
      'p_lat': latitude,
      'p_lng': longitude,
      'p_date': date,
      'p_qr': qrCodeId,
    });
    
    // Broadening the search for pickup_id in the response
    if (res != null) {
      if (res is Map && res.containsKey('pickup_id')) {
        return res['pickup_id'].toString();
      } else if (res is List && res.isNotEmpty && res[0] is Map && res[0].containsKey('pickup_id')) {
        return res[0]['pickup_id'].toString();
      }
    }
    return null;
  }

  Future<void> claimPickup(String pickupId, {bool immediate = true, String? arrivalTime}) async {
    await _supabase.rpc('collector_claim_pickup', params: {
      'p_pickup_id': pickupId,
      'p_mode': immediate ? 'immediate' : 'scheduled',
      'p_scheduled_arrival': arrivalTime,
    });
  }

  Future<Map<String, dynamic>> residentCancelPickup(String pickupId) async {
    try {
      await _supabase.rpc('resident_cancel_pickup', params: {'p_pickup_id': pickupId});
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> collectorCancelPickup(String pickupId) async {
    try {
      await _supabase.rpc('collector_cancel_pickup', params: {'p_pickup_id': pickupId});
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> reschedulePickupAssignment(String pickupId, String newTime) async {
    await _supabase.rpc('collector_reschedule_pickup', params: {
      'p_pickup_id': pickupId,
      'p_scheduled_arrival': newTime,
    });
  }

  Future<void> updatePickupStatus(String pickupId, String status) async {
    await _supabase.rpc('update_pickup_status', params: {
      'p_pickup_id': pickupId,
      'p_status': status,
    });
  }

  Future<void> cancelPickup(String pickupId) async {
    await updatePickupStatus(pickupId, 'cancelled');
  }

  Future<void> markPickupArrived(String pickupId) async {
    await updatePickupStatus(pickupId, 'arrived');
  }

  Future<void> completePickup({required String pickupId, required String qrCode, double? actualWeightKg}) async {
    await _supabase.rpc('collector_complete_pickup', params: {
      'p_pickup_id': pickupId,
      'p_qr_code': qrCode,
      'p_actual_weight': actualWeightKg,
    });
  }

  Future<Map<String, dynamic>> verifyPickupByQr(String qrCode) async {
    final res = await _supabase.from('pickups').select().eq('qr_code_id', qrCode).maybeSingle();
    if (res == null) throw Exception('Invalid QR Code');
    return res;
  }

  // ========================= REWARDS =========================

  Future<List<Map<String, dynamic>>> getRewards() async {
    final res = await _supabase.from('rewards').select().eq('is_active', true).order('points_cost', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> redeemReward(String rewardId, int pointsCost, String mpesaNumber) async {
    await _supabase.rpc('redeem_reward', params: {
      'p_reward_id': rewardId,
      'p_points_cost': pointsCost,
      'p_mpesa_number': mpesaNumber,
    });
  }

  // ========================= NOTIFICATIONS =========================

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final res = await _supabase.from('notifications').select().eq('user_id', userId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> markNotificationRead(String id) async {
    await _supabase.rpc('mark_notification_read', params: {'p_notification_id': id});
  }

  Future<void> markAllNotificationsRead() async {
    await _supabase.rpc('mark_notification_read');
  }

  // ========================= RATINGS =========================

  Future<void> submitRating({required String pickupId, required int rating, String comment = ''}) async {
    await _supabase.rpc('submit_pickup_rating', params: {
      'p_pickup_id': pickupId,
      'p_rating': rating,
      'p_comment': comment,
    });
  }

  // ========================= REPORTS =========================

  Future<void> submitReport({required String issueType, required String location, required String description, String? photoUrl}) async {
    await _supabase.rpc('submit_report', params: {
      'p_issue_type': issueType,
      'p_location': location,
      'p_description': description,
      'p_photo_url': photoUrl,
    });
  }

  // ========================= CHALLENGES =========================

  Future<List<String>> getJoinedChallengeIds() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final res = await _supabase.from('challenge_participants').select('challenge_id').eq('user_id', userId);
    return (res as List).map((e) => e['challenge_id'].toString()).toList();
  }

  Future<List<Map<String, dynamic>>> getAllChallenges() async {
    final res = await _supabase.from('challenges').select().order('ends_at', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getUserChallenges() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final res = await _supabase.from('challenge_participants').select('*, challenges(*)').eq('user_id', userId);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> joinChallenge(String challengeId) async {
    await _supabase.rpc('join_challenge', params: {'p_challenge_id': challengeId});
  }

  // ========================= ANALYTICS =========================

  Future<Map<String, double>> getWasteBreakdown() async {
    final userId = currentUser?.id;
    if (userId == null) return {};
    final pickups = await _supabase.from('pickups').select('waste_type, weight_kg').eq('user_id', userId).eq('status', 'completed');

    final breakdown = <String, double>{};
    for (var p in pickups) {
      final type = p['waste_type'] ?? 'Other';
      final weight = ((p['weight_kg'] ?? 0.0) as num).toDouble();
      breakdown[type] = (breakdown[type] ?? 0) + weight;
    }
    return breakdown;
  }

  Future<int> getUserStreak() async {
    final userId = currentUser?.id;
    if (userId == null) return 0;
    final res = await _supabase.from('pickups').select('id').eq('user_id', userId).eq('status', 'completed');
    return res.length;
  }

  Future<Map<String, dynamic>> getCollectorStats() async {
    try {
      final profile = await getProfile();
      final earningsInfo = await getCollectorEarningsDetailed();
      return {
        'eco_points': profile['eco_points'] ?? 0,
        'total_collections': profile['total_collections'] ?? 0,
        'total_earnings': (earningsInfo['total_earnings'] ?? 0) as int,
        'rating': (profile['rating'] ?? 0.0) as double,
      };
    } catch (_) {
      return {
        'eco_points': 0,
        'total_collections': 0,
        'total_earnings': 0,
        'rating': 0.0,
      };
    }
  }

  Future<Map<String, dynamic>> getCollectorEarningsDetailed() async {
    final userId = currentUser?.id;
    if (userId == null) return {'completed': [], 'total_earnings': 0, 'total_points': 0};
    final completed = await _supabase.from('pickups').select().eq('collector_id', userId).eq('status', 'completed');

    int totalEarnings = 0;
    for (var p in completed) {
      totalEarnings += ((p['cost_kes'] ?? 0) as num).toInt();
    }
    return {'completed': completed, 'total_earnings': totalEarnings};
  }

  Future<List<Map<String, dynamic>>> getLeaderboard({
    String period = 'all',
    String? sortBy,
    bool isNeighborhood = false,
  }) async {
    final sortCol = sortBy ?? 'eco_points';
    final res = await _supabase.from('profiles').select('full_name, eco_points, co2_saved').order(sortCol, ascending: false).limit(50);
    return List<Map<String, dynamic>>.from(res);
  }

  // ========================= REFERRAL =========================

  Future<String> getReferralCode() async {
    final profile = await getProfile();
    return profile['referral_code'] ?? 'GC-WELCOME';
  }

  // ========================= STORAGE =========================

  Future<String?> uploadWastePhoto(Uint8List bytes, String ext) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _supabase.storage.from('waste-photos').uploadBinary(fileName, bytes);
    return _supabase.storage.from('waste-photos').getPublicUrl(fileName);
  }

  // ========================= APP MAINTENANCE =========================
  // ========================= MAPS =========================

  Future<void> launchMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
