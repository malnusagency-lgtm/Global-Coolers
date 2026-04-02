import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../providers/user_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    // Check if first launch
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    if (!hasSeenOnboarding) {
      if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      try {
        final userProvider = context.read<UserProvider>();
        
        await userProvider.loadUserData().timeout(const Duration(seconds: 10));
        
        if (!userProvider.isDataLoaded) {
          int retry = 0;
          while (!userProvider.isDataLoaded && retry < 20) {
            await Future.delayed(const Duration(milliseconds: 100));
            retry++;
          }
        }

        if (!mounted) return;
        final route = userProvider.isCollector ? '/collector-dashboard' : '/home';
        Navigator.pushReplacementNamed(context, route);
      } catch (e) {
        if (mounted) Navigator.pushReplacementNamed(context, '/landing');
      }
    } else {
      if (mounted) Navigator.pushReplacementNamed(context, '/landing');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              AppColors.primary.withOpacity(0.05),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Centered Logo with Leaf Branded Packaging look
              TweenAnimationBuilder(
                duration: const Duration(seconds: 1),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 180,
                  height: 180,
                  padding: const EdgeInsets.all(32),
                  child: Image.asset('assets/images/leaf_logo.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 48),
              
              // Brand Name with spacing
              const Text(
                'GLOBAL COOLERS',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4.0,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'SMARTER WASTE • CLEANER FUTURE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: AppColors.primary,
                  ),
                ),
              ),
              
              const SizedBox(height: 80),
              
              // Loading
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
