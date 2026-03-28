import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';

/// Centralized API service that communicates with the live Node.js backend
/// hosted on Render. Auth is still handled by Supabase; this service handles
/// all data CRUD operations through the backend API.
class ApiService {
  static final String _baseUrl = SupabaseConfig.apiBaseUrl;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  // ─── Health Check ──────────────────────────────────────────────

  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      print('ApiService health check failed: $e');
      return false;
    }
  }

  // ─── User Profile ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/auth/profile/$userId'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['user'];
    }
    throw Exception(data['message'] ?? 'Failed to fetch profile');
  }

  // ─── Pickups ───────────────────────────────────────────────────

  static Future<List<dynamic>> getPickups(String userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/pickups/$userId'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['pickups'] as List<dynamic>;
    }
    return [];
  }

  static Future<Map<String, dynamic>> schedulePickup({
    required String userId,
    required String date,
    required String wasteType,
    required String address,
    String? photoUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/pickups/schedule'),
      headers: _headers,
      body: jsonEncode({
        'userId': userId,
        'date': date,
        'wasteType': wasteType,
        'address': address,
        'photoUrl': photoUrl,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data['success'] == true) {
      return data['pickup'];
    }
    throw Exception(data['message'] ?? 'Failed to schedule pickup');
  }

  // ─── Rewards ───────────────────────────────────────────────────

  static Future<List<dynamic>> getRewards() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/rewards'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['rewards'] as List<dynamic>;
    }
    return [];
  }

  static Future<bool> redeemReward({
    required String userId,
    required String rewardId,
    required int pointsCost,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/rewards/redeem'),
      headers: _headers,
      body: jsonEncode({
        'userId': userId,
        'rewardId': rewardId,
        'pointsCost': pointsCost,
      }),
    );

    final data = jsonDecode(response.body);
    return response.statusCode == 200 && data['success'] == true;
  }

  // ─── Leaderboard ───────────────────────────────────────────────

  static Future<List<dynamic>> getLeaderboard() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/leaderboard'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['leaderboard'] as List<dynamic>;
    }
    return [];
  }

  // ─── Reports ───────────────────────────────────────────────────

  static Future<bool> submitReport({
    required String userId,
    required String issueType,
    required String location,
    required String description,
    String? photoUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/reports'),
      headers: _headers,
      body: jsonEncode({
        'userId': userId,
        'issueType': issueType,
        'location': location,
        'description': description,
        'photoUrl': photoUrl,
      }),
    );

    final data = jsonDecode(response.body);
    return response.statusCode == 201 && data['success'] == true;
  }

  // ─── Update Profile (e.g. location for collectors) ─────────────

  static Future<bool> updateProfile({
    required String userId,
    String? fullName,
    double? latitude,
    double? longitude,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;

    final response = await http.put(
      Uri.parse('$_baseUrl/api/auth/profile/$userId'),
      headers: _headers,
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);
    return response.statusCode == 200 && data['success'] == true;
  }
}
