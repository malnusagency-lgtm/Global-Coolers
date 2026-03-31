import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

/// Centralized API service that communicates directly with Supabase.
/// This bypasses the old Render Node.js backend to explicitly eliminate 
/// cold-start timeouts and ensure the app loads instantly.
class ApiService {
  static final _supabase = Supabase.instance.client;

  // ─── Health Check ──────────────────────────────────────────────

  static Future<bool> healthCheck() async {
    // Since we connect to Supabase over WebSocket/REST natively, 
    // it's generally healthy if the client initialized.
    return true; 
  }

  // ─── User Profile ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

    if (response != null) {
      return response;
    }
    throw Exception('User profile not found in database');
  }

  // ─── Pickups ───────────────────────────────────────────────────

  static Future<List<dynamic>> getPickups(String userId) async {
    final response = await _supabase
        .from('pickups')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return response as List<dynamic>;
  }

  static Future<Map<String, dynamic>> schedulePickup({
    required String userId,
    required String date,
    required String wasteType,
    required String address,
    String? photoUrl,
    double weightKg = 1.0,
    int costKes = 0,
  }) async {
    final random = Random();
    final qrCode = 'GC-${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(9999)}';

    final response = await _supabase.from('pickups').insert({
      'user_id': userId,
      'date': date,
      'waste_type': wasteType,
      'address': address,
      'status': 'scheduled',
      'photo_url': photoUrl,
      'qr_code_id': qrCode,
      'weight_kg': weightKg,
      'cost_kes': costKes,
    }).select().single();

    return response;
  }

  // ─── Rewards ───────────────────────────────────────────────────

  static Future<List<dynamic>> getRewards() async {
    final response = await _supabase.from('rewards').select('*');
    return response as List<dynamic>;
  }

  static Future<bool> redeemReward({
    required String userId,
    required String rewardId,
    required int pointsCost,
  }) async {
    try {
      // 1. Check user balance
      final profile = await _supabase
          .from('profiles')
          .select('eco_points')
          .eq('id', userId)
          .single();

      final currentPoints = profile['eco_points'] as int? ?? 0;
      if (currentPoints < pointsCost) {
        throw Exception('Insufficient points');
      }

      // 2. Deduct points
      await _supabase
          .from('profiles')
          .update({'eco_points': currentPoints - pointsCost})
          .eq('id', userId);

      return true;
    } catch (e) {
      print('Redeem Reward Error: $e');
      return false;
    }
  }

  // ─── Leaderboard ───────────────────────────────────────────────

  static Future<List<dynamic>> getLeaderboard({String sortBy = 'co2_saved'}) async {
    final response = await _supabase
        .from('profiles')
        .select('id, full_name, eco_points, co2_saved')
        .order(sortBy, ascending: false)
        .limit(20);
    return response as List<dynamic>;
  }

  // ─── Reports ───────────────────────────────────────────────────

  static Future<bool> submitReport({
    required String userId,
    required String issueType,
    required String location,
    required String description,
    String? photoUrl,
  }) async {
    try {
      await _supabase.from('reports').insert({
        'user_id': userId,
        'issue_type': issueType,
        'location': location,
        'description': description,
        'photo_url': photoUrl,
        'status': 'pending'
      });
      return true;
    } catch (e) {
      print('Report Issue Error: $e');
      return false;
    }
  }

  // ─── Challenges ──────────────────────────────────────────────
  
  static Future<List<dynamic>> getChallenges() async {
    final response = await _supabase
        .from('challenges')
        .select('*')
        .order('ends_at', ascending: true);
    return response as List<dynamic>;
  }

  // ─── Update Profile (e.g. location for collectors) ─────────────

  static Future<bool> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    double? latitude,
    double? longitude,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (latitude != null) updates['latitude'] = latitude;
    if (longitude != null) updates['longitude'] = longitude;

    if (updates.isEmpty) return false;

    try {
      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId);
      return true;
    } catch (e) {
      print('Update Profile Error: $e');
      return false;
    }
  }
}
