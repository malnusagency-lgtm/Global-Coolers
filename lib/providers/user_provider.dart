import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';

enum AppRole { resident, collector }

class UserProvider extends ChangeNotifier {
  String _userId = '';
  String _userName = '';
  AppRole _role = AppRole.resident;
  int _ecoPoints = 0;
  int _totalWasteDiverted = 0;
  
  bool _isLoading = true;
  String? _lastError;

  // Getters
  String get userId => _userId;
  String get userName => _userName;
  AppRole get role => _role;
  int get ecoPoints => _ecoPoints;
  int get totalWasteDiverted => _totalWasteDiverted;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  UserProvider() {
    _init();
  }

  Future<void> _init() async {
    await loadUserData();
  }

  /// Loads user data. Since we now connect directly to Supabase via ApiService,
  /// there are no cold-start delays and we only need a basic request.
  Future<void> loadUserData() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      _userId = currentUser.id;

      final data = await ApiService.getUserProfile(_userId);
      _userName = data['full_name'] ?? 'Guest';
      _ecoPoints = data['eco_points'] ?? 0;
      _totalWasteDiverted = data['co2_saved'] ?? 0;
      _role = data['role'] == 'collector' ? AppRole.collector : AppRole.resident;
      _lastError = null;

    } catch (e) {
      _lastError = e.toString();
      _userName = 'Guest';
      debugPrint('Failed to load user data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> redeemReward(int cost, {String rewardId = 'REWARD'}) async {
    return redeemPoints(cost, rewardId: rewardId);
  }

  Future<bool> redeemPoints(int cost, {String rewardId = 'REWARD'}) async {
    if (_userId.isEmpty) return false;

    try {
      final success = await ApiService.redeemReward(
        userId: _userId,
        rewardId: rewardId,
        pointsCost: cost,
      );
      if (success) {
        _ecoPoints -= cost;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Redeem error: $e');
      return false;
    }
  }

  void addPoints(int amount) {
    _ecoPoints += amount;
    notifyListeners();
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _userId = '';
    _userName = '';
    _ecoPoints = 0;
    _totalWasteDiverted = 0;
    _role = AppRole.resident;
    _lastError = null;
    notifyListeners();
  }
}
