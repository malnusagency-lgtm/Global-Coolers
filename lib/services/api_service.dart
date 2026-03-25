import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  
  // Generic helper for error handling
  Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['success'] == true) {
        return jsonResponse;
      } else {
        throw Exception(jsonResponse['message'] ?? 'API Request Failed');
      }
    } else {
      throw Exception('HTTP Error: ${response.statusCode}');
    }
  }

  /// Fetches the user profile containing name, ecoPoints, wasteDiverted, etc.
  Future<Map<String, dynamic>> fetchProfile() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.profile));
      final data = await _handleResponse(response);
      return data['user'];
    } catch (e) {
      // Re-throw or return mock data as fallback if desired
      print('ApiService Error: $e');
      rethrow;
    }
  }

  /// Fetches the list of rewards
  Future<List<dynamic>> fetchRewards() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.rewards));
      final data = await _handleResponse(response);
      return data['rewards'];
    } catch (e) {
      print('ApiService Error: $e');
      rethrow;
    }
  }

  /// Fetches the list of pickups
  Future<List<dynamic>> fetchPickups() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.pickups));
      final data = await _handleResponse(response);
      return data['pickups'];
    } catch (e) {
      print('ApiService Error: $e');
      rethrow;
    }
  }

  /// Submits a scheduling request
  Future<Map<String, dynamic>> schedulePickup(
      String date, String wasteType, String address) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.schedulePickup),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'date': date,
          'wasteType': wasteType,
          'address': address,
        }),
      );
      final data = await _handleResponse(response);
      return data['pickup'];
    } catch (e) {
      print('ApiService Error: $e');
      rethrow;
    }
  }
}
