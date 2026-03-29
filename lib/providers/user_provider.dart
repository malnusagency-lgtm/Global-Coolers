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

  /// Loads user data with retry logic (up to [maxAttempts] attempts).
  /// The Render backend may cold-start, so we retry with exponential backoff.
  Future<void> loadUserData({int maxAttempts = 20}) async {
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

      // Retry loop with exponential backoff for cold-start resilience
      Exception? lastException;
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final data = await ApiService.getUserProfile(_userId);
          _userName = data['full_name'] ?? 'Guest';
          _ecoPoints = data['eco_points'] ?? 0;
          _totalWasteDiverted = data['co2_saved'] ?? 0;
          _role = data['role'] == 'collector' ? AppRole.collector : AppRole.resident;
          _lastError = null;
          return; // Success — exit
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
          debugPrint('Attempt $attempt/$maxAttempts failed: $e');

          if (attempt < maxAttempts) {
            // Exponential backoff: 500ms, 1s, 2s, 3s... capped at 5s
            final delay = Duration(milliseconds: (500 * attempt).clamp(500, 5000));
            await Future.delayed(delay);
          }
        }
      }

      // All attempts exhausted — try Supabase directly as fallback
      try {
        debugPrint('Backend unavailable, falling back to Supabase direct...');
        final profile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', _userId)
            .maybeSingle();

        if (profile != null) {
          _userName = profile['full_name'] ?? 'Guest';
          _ecoPoints = profile['eco_points'] ?? 0;
          _totalWasteDiverted = profile['co2_saved'] ?? 0;
          _role = profile['role'] == 'collector' ? AppRole.collector : AppRole.resident;
          _lastError = null;
          return;
        }
      } catch (fallbackError) {
        debugPrint('Supabase fallback also failed: $fallbackError');
      }

      // Everything failed
      _lastError = lastException?.toString() ?? 'Failed to load profile';
      _userName = 'Guest';
      debugPrint('All $maxAttempts attempts exhausted: $lastException');
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
