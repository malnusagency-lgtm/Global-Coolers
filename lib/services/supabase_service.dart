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
  Future<void> schedulePickup(String date, String wasteType, String address) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    try {
      await _supabase.from('pickups').insert({
        'user_id': userId,
        'date': date,
        'waste_type': wasteType,
        'address': address,
        'status': 'scheduled',
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

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
