import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:global_coolers/config/supabase_config.dart';

void main() {
  test('Test Pickups and Profile Fetch', () async {
    final supabase = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    // login as the user we created
    final AuthResponse res = await supabase.auth.signInWithPassword(
      email: 'alexfyber2236@gmail.com',
      password: 'Buda@2040'
    );
    
    final userId = res.user?.id;
    print('Logged in user: $userId');

    // 1. Fetch Profile
    try {
      final profile = await supabase.from('profiles').select().eq('id', userId!).single();
      print('Profile success: $profile');
    } catch (e) {
      print('Profile fetch failed: $e');
    }

    // 2. Schedule Pickup
    try {
      final pickup = await supabase.from('pickups').insert({
        'user_id': userId,
        'date': '2026-03-31 8:00 - 11:00 AM',
        'waste_type': 'Plastic',
        'address': 'Plot 45, Kilimani',
        'status': 'scheduled',
        'qr_code': 'TEST-QR-123',
      }).select().single();
      print('Pickup schedule success: $pickup');
    } catch (e) {
      print('Pickup schedule failed: $e');
    }
  });
}
