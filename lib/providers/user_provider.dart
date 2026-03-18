import 'package:flutter/foundation.dart';
import '../services/mock_data_service.dart';

enum AppRole { resident, collector, admin }

class UserProvider extends ChangeNotifier {
  String _userName = '';
  AppRole _role = AppRole.resident;
  int _ecoPoints = 0;
  int _totalWasteDiverted = 0;
  bool _isLoading = true;

  // Getters
  String get userName => _userName;
  AppRole get role => _role;
  int get ecoPoints => _ecoPoints;
  int get totalWasteDiverted => _totalWasteDiverted;
  bool get isLoading => _isLoading;

  UserProvider() {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await MockDataService.fetchUserProfile();
      _userName = data['name'];
      _ecoPoints = data['ecoPoints'];
      _totalWasteDiverted = data['totalWasteDiverted'];
      
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
      debugPrint('Error loading user data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> redeemPoints(int cost) async {
    if (_ecoPoints < cost) return false;

    // Simulate backend call
    final success = await MockDataService.redeemReward('reward_id', cost);
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
