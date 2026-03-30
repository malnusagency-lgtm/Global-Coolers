import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:global_coolers/config/supabase_config.dart';

void main() {
  test('Test Auth and DB Flow', () async {
    final supabase = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    final randomEmail = 'testuser${Random().nextInt(99999)}@example.com';
    final password = 'Password@123';
    
    print('1. Signing up $randomEmail');
    try {
      final AuthResponse res = await supabase.auth.signUp(
        email: randomEmail,
        password: password,
      );
      final userId = res.user?.id;
      print('Signup Success: $userId');

      if (userId == null) return;

      print('2. Inserting Profile');
      try {
        await supabase.from('profiles').upsert({
          'id': userId,
          'email': randomEmail,
          'full_name': 'Test User',
        });
        print('Profile Inserted');
      } catch (e) {
        print('Profile Insert Error: $e');
      }

      print('3. Selecting Profile');
      try {
        final profile = await supabase.from('profiles').select().eq('id', userId).single();
        print('Profile Selected: $profile');
      } catch (e) {
        print('Profile Select Error: $e');
      }

      print('4. Scheduling Pickup');
      try {
        final pickup = await supabase.from('pickups').insert({
          'user_id': userId,
          'date': '2026-03-31 8:00 - 11:00 AM',
          'waste_type': 'Plastic',
          'address': 'Plot 45, Kilimani',
          'status': 'scheduled',
          'qr_code': 'TEST-QR-123',
        }).select().single();
        print('Pickup Scheduled: $pickup');
      } catch (e) {
        print('Pickup Schedule Error: $e');
      }
    } catch (e) {
      print('Overall Error: $e');
    }
  });
}
