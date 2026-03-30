import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:global_coolers/config/supabase_config.dart';

void main() {
  test('Debug Schema Issue', () async {
    final supabase = SupabaseClient(
      SupabaseConfig.url, 
      SupabaseConfig.anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    
    // Attempt to fetch 1 row from profiles to see its keys
    try {
      final data = await supabase.from('profiles').select().limit(1);
      if (data.isNotEmpty) {
        print('Profile columns exposed to anon/auth: ${data.first.keys.toList()}');
      } else {
        print('No profiles exist or RLS blocked read.');
      }
    } catch(e) {
      print('Profiles Query Error: $e');
    }

    // Checking insertions
    print('Let us attempt inserting a dummy profile:');
    try {
      await supabase.from('profiles').insert({
        'id': 'd1b26417-6ff7-4ef8-a55e-deeba629d8d6', // fake UUID
        'email': 'test@example.com',
        'phone': '12345',
        'full_name': 'Test',
        'role': 'resident'
      });
    } catch(e) {
      print('Insert Error (maybe missing column?): $e');
    }

    try {
      final pickupData = await supabase.from('pickups').select().limit(1);
      if (pickupData.isNotEmpty) {
        print('Pickup columns: ${pickupData.first.keys.toList()}');
      }
    } catch(e) {
      print('Pickups Query Error: $e');
    }
  });
}
