import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Loads user data with Instant Offline Caching.
  /// First instantly paints the dashboard with cached data, then quietly updates from Supabase.
  Future<void> loadUserData() async {
    _isLoading = true;
    _lastError = null;

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      _userId = currentUser.id;

      // 1. FAST PATH: Pull locally cached data for instant UI
      final prefs = await SharedPreferences.getInstance();
      final cachedName = prefs.getString('cache_userName');
      if (cachedName != null) {
        _userName = cachedName;
        _ecoPoints = prefs.getInt('cache_ecoPoints') ?? 0;
        _totalWasteDiverted = prefs.getInt('cache_co2') ?? 0;
        _role = (prefs.getString('cache_role') == 'collector') ? AppRole.collector : AppRole.resident;
        _isLoading = false; // Turn off spinner immediately!
        notifyListeners();
      } else {
        notifyListeners(); // Show spinner if completely cold
      }

      // 2. BACKGROUND UPDATES: Fetch latest values explicitly
      final data = await ApiService.getUserProfile(_userId);
      _userName = data['full_name'] ?? 'Guest';
      _ecoPoints = data['eco_points'] ?? 0;
      _totalWasteDiverted = data['co2_saved'] ?? 0;
      _role = data['role'] == 'collector' ? AppRole.collector : AppRole.resident;
      _lastError = null;

      // Update Local cache quietly
      await prefs.setString('cache_userName', _userName);
      await prefs.setInt('cache_ecoPoints', _ecoPoints);
      await prefs.setInt('cache_co2', _totalWasteDiverted);
      await prefs.setString('cache_role', _role == AppRole.collector ? 'collector' : 'resident');

    } catch (e) {
      if (_userName.isEmpty || _userName == 'Guest') {
        _lastError = e.toString();
        _userName = 'Guest';
      }
      debugPrint('Failed to fetch latest user data: $e');
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      } else {
        // Just silently notify if we already stopped the spinner for cache
        notifyListeners();
      }
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
    
    // Wipe local cache entirely for privacy
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _userId = '';
    _userName = '';
    _ecoPoints = 0;
    _totalWasteDiverted = 0;
    _role = AppRole.resident;
    _lastError = null;
    notifyListeners();
  }
}
