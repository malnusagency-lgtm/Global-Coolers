import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

enum AppRole { resident, collector, admin }

class UserProvider extends ChangeNotifier {
  String _userName = '';
  AppRole _role = AppRole.resident;
  int _ecoPoints = 0;
  int _totalWasteDiverted = 0;
  final ApiService _apiService = ApiService();
  
  bool _isLoading = true;

  // Getters
  String get userName => _userName;
  AppRole get role => _role;
  int get ecoPoints => _ecoPoints;
  int get totalWasteDiverted => _totalWasteDiverted;
  bool get isLoading => _isLoading;

  UserProvider() {
    loadUserData();
  }

  Future<void> loadUserData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.fetchProfile();
      _userName = data['name'] ?? 'Muthoni N.';
      _ecoPoints = data['ecoPoints'] ?? 0;
      _totalWasteDiverted = data['co2Saved'] ?? 0;
        
        switch (data['role']) {
          case 'collector':
            _role = AppRole.collector;
            break;
          case 'admin':
            _role = AppRole.admin;
            break;
          default:
            _role = AppRole.resident;
        }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      // Fallbacks in case server isn't running yet
      _userName = 'Muthoni N.';
      _ecoPoints = 500;
      _totalWasteDiverted = 120;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> redeemPoints(int cost) async {
    if (_ecoPoints < cost) return false;

    // For now, simulate backend call as the backend doesn't have a redeem route yet
    // In a real scenario, we would call: await _apiService.redeemReward(cost);
    final success = true; // Simulated success
    if (success) {
      _ecoPoints -= cost;
      notifyListeners();
      return true;
    }
    return false;
  }

  void addPoints(int amount) {
    _ecoPoints += amount;
    notifyListeners();
  }
}
