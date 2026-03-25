import '../services/supabase_service.dart';

enum AppRole { resident, collector }

class UserProvider extends ChangeNotifier {
  String _userName = '';
  AppRole _role = AppRole.resident;
  int _ecoPoints = 0;
  int _totalWasteDiverted = 0;
  final SupabaseService _supabaseService = SupabaseService();
  
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
      final data = await _supabaseService.getProfile();
      _userName = data['full_name'] ?? 'Guest';
      _ecoPoints = data['eco_points'] ?? 0;
      _totalWasteDiverted = data['co2_saved'] ?? 0;
      _role = data['role'] == 'collector' ? AppRole.collector : AppRole.resident;
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

    try {
      await _supabaseService.redeemReward('REWARD_ID', cost);
      await loadUserData();
      return true;
    } catch (e) {
      debugPrint('Redeem error: $e');
      return false;
    }

  void addPoints(int amount) {
    _ecoPoints += amount;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _supabaseService.signOut();
    _userName = '';
    _ecoPoints = 0;
    _role = AppRole.resident;
    notifyListeners();
  }
}
