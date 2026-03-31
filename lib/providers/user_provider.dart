import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';

enum AppRole { resident, collector }

class UserProvider extends ChangeNotifier {
  String _userId = '';
  String _userName = '';
  String _email = '';
  String _phone = '';
  AppRole _role = AppRole.resident;
  int _ecoPoints = 0;
  int _totalWasteDiverted = 0;
  String? _address;
  bool _isOnline = false;
  double? _latitude;
  double? _longitude;
  
  bool _isLoading = true;
  String? _lastError;

  // Getters
  String get userId => _userId;
  String get userName => _userName;
  String get email => _email;
  String get phone => _phone;
  AppRole get role => _role;
  int get ecoPoints => _ecoPoints < 0 ? 0 : _ecoPoints;
  int get totalWasteDiverted => _totalWasteDiverted;
  String? get address => _address;
  bool get isOnline => _isOnline;
  bool get isCollector => _role == AppRole.collector;
  String get fullName => _userName;
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
    if (_isLoading && _userId.isNotEmpty) return; // Already loading
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
        _email = prefs.getString('cache_email') ?? '';
        _phone = prefs.getString('cache_phone') ?? '';
        _address = prefs.getString('cache_address');
        _isLoading = false; // Turn off spinner immediately!
        notifyListeners();
      } else {
        notifyListeners(); // Show spinner if completely cold
      }

      // 2. BACKGROUND UPDATES: Fetch latest values from Supabase
      Map<String, dynamic>? data;
      Exception? fetchError;
      
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          data = await ApiService.getUserProfile(_userId);
          break;
        } catch (e) {
          fetchError = e is Exception ? e : Exception(e.toString());
          debugPrint('getUserProfile attempt $attempt failed: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      }

      if (data != null) {
        _userName = data['full_name'] ?? 'User';
        _ecoPoints = data['eco_points'] ?? 0;
        _totalWasteDiverted = data['co2_saved'] ?? 0;
        final roleStr = (data['role'] as String? ?? 'resident').toLowerCase();
        _role = roleStr == 'collector' ? AppRole.collector : AppRole.resident;

        _isOnline = data['is_online'] ?? false;
        _latitude = (data['latitude'] as num?)?.toDouble();
        _longitude = (data['longitude'] as num?)?.toDouble();
        _email = data['email'] ?? currentUser.email ?? '';
        _phone = data['phone'] ?? '';
        _address = data['address'];
        _lastError = null;

        // Update local cache quietly
        await prefs.setString('cache_userName', _userName);
        await prefs.setInt('cache_ecoPoints', _ecoPoints);
        await prefs.setInt('cache_co2', _totalWasteDiverted);
        await prefs.setString('cache_role', _role == AppRole.collector ? 'collector' : 'resident');
        await prefs.setString('cache_email', _email);
        await prefs.setString('cache_phone', _phone);
        if (_address != null) await prefs.setString('cache_address', _address!);
      } else if (_userName.isEmpty || _userName == 'User') {
        // Profile doesn't exist yet — use auth email as fallback
        _userName = currentUser.email?.split('@').first ?? 'User';
        _email = currentUser.email ?? '';
        _lastError = fetchError?.toString();
      }

    } catch (e) {
      if (_userName.isEmpty || _userName == 'User') {
        _lastError = e.toString();
        _userName = 'User';
      }
      debugPrint('Failed to fetch latest user data: $e');
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }
  }

  Future<void> fetchProfile() async {
    await loadUserData();
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

  Future<void> toggleOnlineStatus() async {
    if (_userId.isEmpty || !isCollector) return;
    
    final newStatus = !_isOnline;
    
    // Optimistic update
    _isOnline = newStatus;
    notifyListeners();

    try {
      await SupabaseService().updateOnlineStatus(newStatus);
    } catch (e) {
      // Revert if error occurs
      _isOnline = !newStatus;
      notifyListeners();
      debugPrint('Toggle online status error: $e');
      throw Exception('Failed to go online. Please ensure "is_online" column (boolean) exists in your Supabase "profiles" table.');
    }
  }


  Future<void> updateCurrentLocation(double lat, double lng) async {
    _latitude = lat;
    _longitude = lng;
    if (isCollector && _isOnline) {
      await SupabaseService().updateLocation(lat, lng);
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    
    // Wipe local cache entirely for privacy
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _userId = '';
    _userName = '';
    _email = '';
    _phone = '';
    _ecoPoints = 0;
    _totalWasteDiverted = 0;
    _role = AppRole.resident;
    _lastError = null;
    notifyListeners();
  }
}
