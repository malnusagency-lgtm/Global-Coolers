import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  final _supabase = Supabase.instance.client;
  
  // Login as a collector
  await _supabase.auth.signInWithPassword(
    email: 'collector@example.com',
    password: 'password123'
  );

  try {
    await _supabase.rpc(
      'collector_claim_pickup',
      params: {
        'p_pickup_id': '00000000-0000-0000-0000-000000000000',
        'p_is_immediate': true,
        'p_scheduled_arrival': null,
      },
    );
    print("CLAIM SUCCESS!");
  } catch(e) {
    print("CLAIM ERROR: $e");
  }
}
