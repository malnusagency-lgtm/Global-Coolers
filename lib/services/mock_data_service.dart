import 'dart:async';

class MockDataService {
  // Simulate network delay
  static Future<void> _delay([int milliseconds = 800]) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  static Future<Map<String, dynamic>> fetchUserProfile() async {
    await _delay();
    return {
      'name': 'Wanjiku',
      'role': 'resident',
      'ecoPoints': 1250,
      'totalWasteDiverted': 145, // kg
    };
  }

  static Future<bool> redeemReward(String rewardId, int pointsCost) async {
    await _delay(1200); // slightly longer delay for "transaction"
    // Simulate successful redemption
    return true;
  }

  static Future<bool> schedulePickup(Map<String, dynamic> pickupData) async {
    await _delay(1500);
    return true; // Simulate success
  }

  static Future<bool> submitIssueReport(Map<String, dynamic> reportData) async {
    await _delay(1000);
    return true; // Simulate success
  }
}
