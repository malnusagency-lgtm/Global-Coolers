import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:global_coolers/config/supabase_config.dart';

void main() {
  test('Final End-to-End Database Flow Test', () async {
    // Note: Ensure SupabaseConfig is correctly set up with project URL and Anon Key
    final supabase = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    final randomId = Random().nextInt(99999).toString();
    final testEmail = 'tester$randomId@globalcoolers.com';
    final password = 'TestPassword123!';
    
    print('--- STARTING GLOBAL COOLERS E2E DATABASE TEST ---');

    try {
      // 1. Auth Signup (Triggers handle_new_user and 500pt bonus)
      print('1. Registering test user: $testEmail');
      final AuthResponse authRes = await supabase.auth.signUp(
        email: testEmail,
        password: password,
        data: {
          'full_name': 'Test User $randomId',
          'role': 'resident',
        },
      );
      
      final userId = authRes.user?.id;
      if (userId == null) throw Exception('Signup failed - No User ID');
      print('✓ Signup Success: $userId');

      // Wait a moment for trigger to complete
      print('... waiting for database triggers ...');
      await Future.delayed(const Duration(seconds: 2));

      // 2. Profile Verification
      print('2. Verifying Profile & Initial Points');
      final profile = await supabase.from('profiles').select().eq('id', userId).single();
      print('✓ Profile Data: $profile');
      
      if (profile['eco_points'] != 500) {
        throw Exception('Signup Bonus Failed: Expected 500, got ${profile['eco_points']}');
      }
      print('✓ Signup Bonus (500 Pts) verified!');

      // 3. Notification Check
      print('3. Verifying Welcome Notification');
      final notifications = await supabase.from('notifications').select().eq('user_id', userId);
      print('✓ Notifications: ${notifications.length} found');
      if (notifications.isEmpty) throw Exception('Welcome notification not found');

      // 4. Pickup Scheduling (Resolving the reported error)
      print('4. Scheduling Pickup (Test qr_code_id and status)');
      final pickup = await supabase.from('pickups').insert({
        'user_id': userId,
        'date': '2026-04-02 10:00 AM',
        'waste_type': 'Plastic/PET',
        'address': 'Test Avenue, Nairobi',
        'status': 'scheduled',
        'weight_kg': 5.5,
        'qr_code_id': 'TEST-QR-$randomId',
      }).select().single();
      print('✓ Pickup Scheduled: ${pickup['id']}');

      // 5. Completion Logic (Testing Point Trigger)
      print('5. Simulating Completion (Status update trigger)');
      await supabase.from('pickups').update({'status': 'completed'}).eq('id', pickup['id']);
      print('✓ Pickup marked as completed');

      // Wait for point increment trigger
      await Future.delayed(const Duration(seconds: 1));

      // 6. Final Point Check (500 base + 5.5kg * 10pts = 555)
      final finalProfile = await supabase.from('profiles').select('eco_points').eq('id', userId).single();
      print('✓ Final Points: ${finalProfile['eco_points']}');
      
      if ((finalProfile['eco_points'] as int) < 555) {
        throw Exception('Point awarding trigger failed: Expected ~555, got ${finalProfile['eco_points']}');
      }
      print('✓ Point awarding logic verified!');

      print('--- TEST SUCCESS: ALL DB FLOWS FUNCTIONAL ---');

    } catch (e) {
      print('❌ TEST FAILED: $e');
      rethrow;
    }
  });
}
