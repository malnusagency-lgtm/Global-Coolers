import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

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
      print('SupabaseService Profile Error: $e');
      rethrow;
    }
  }

  /// Fetches rewards from the 'rewards' table
  Future<List<dynamic>> getRewards() async {
    try {
      final response = await _supabase.from('rewards').select();
      return response as List<dynamic>;
    } catch (e) {
      print('SupabaseService Rewards Error: $e');
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
      print('SupabaseService Pickups Error: $e');
      return [];
    }
  }

  /// Schedules a new waste pickup
  Future<void> schedulePickup({
    required String date, 
    required String wasteType, 
    required String address,
    String? photoUrl,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    try {
      await _supabase.from('pickups').insert({
        'user_id': userId,
        'date': date,
        'waste_type': wasteType,
        'address': address,
        'status': 'scheduled',
        'photo_url': photoUrl,
      });
    } catch (e) {
      print('SupabaseService Schedule Error: $e');
      rethrow;
    }
  }

  /// Redeems a reward (placeholder logic)
  Future<void> redeemReward(String rewardId, int pointsCost) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    // This would typically involve a function or a transaction to deduct points
    // For now, we'll just simulate the deduction
    final profile = await getProfile();
    final currentPoints = profile['eco_points'] as int;

    if (currentPoints < pointsCost) throw Exception('Insufficient points');

    await _supabase.from('profiles').update({
      'eco_points': currentPoints - pointsCost,
    }).eq('id', userId);
  }

  /// Uploads a waste photo to Supabase Storage
  Future<String?> uploadWastePhoto(File file) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'waste-photos/$fileName';

    try {
      await _supabase.storage.from('waste-photos').upload(path, file);
      
      // Get public URL
      final publicUrl = _supabase.storage.from('waste-photos').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print('Upload Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Verifies a pickup by its QR code (Collector side)
  Future<Map<String, dynamic>> verifyPickupByQr(String qrCode) async {
    try {
      final response = await _supabase
          .from('pickups')
          .select('*, profiles(full_name, eco_points)')
          .eq('qr_code', qrCode)
          .single();
      
      if (response['status'] == 'completed') {
        throw Exception('This pickup has already been verified.');
      }

      return response;
    } catch (e) {
      print('QR Verification Error: $e');
      rethrow;
    }
  }

  /// Completes a pickup and awards points (Collector side)
  Future<void> completePickup(String pickupId, String userId, int pointsToAward) async {
    try {
      // 1. Update pickup status
      await _supabase
          .from('pickups')
          .update({'status': 'completed'})
          .eq('id', pickupId);

      // 2. Fetch current user points
      final profile = await _supabase
          .from('profiles')
          .select('eco_points')
          .eq('id', userId)
          .single();
      
      final currentPoints = profile['eco_points'] as int;

      // 3. Award points
      await _supabase
          .from('profiles')
          .update({'eco_points': currentPoints + pointsToAward})
          .eq('id', userId);
    } catch (e) {
      print('Complete Pickup Error: $e');
      rethrow;
    }
  }

  /// Streams the location of a specific user (Collector)
  Stream<List<Map<String, dynamic>>> streamLocation(String userId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId);
  }

  /// Updates the current user's location (Collector side)
  Future<void> updateLocation(double lat, double lng) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('profiles').update({
        'latitude': lat,
        'longitude': lng,
      }).eq('id', userId);
    } catch (e) {
      print('Update Location Error: $e');
    }
  }

  /// Fetches top users for the leaderboard
  Future<List<dynamic>> getLeaderboard() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .order('eco_points', ascending: false)
          .limit(20);
      return response as List<dynamic>;
    } catch (e) {
      print('Leaderboard Error: $e');
      return [];
    }
  }

  /// Fetches challenges (Community Challenges)
  Future<List<dynamic>> getChallenges(String status) async {
    try {
      final response = await _supabase
          .from('challenges')
          .select()
          .eq('status', status);
      return response as List<dynamic>;
    } catch (e) {
      print('Challenges Error: $e');
      return [];
    }
  }
}
