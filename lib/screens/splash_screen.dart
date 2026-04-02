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
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.primary.withOpacity(0.02),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Clean Icon-Only Branded Logo in Rounded Box
              TweenAnimationBuilder(
                duration: const Duration(seconds: 1),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.9 + (0.1 * value),
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: Image.asset('assets/images/leaf_logo.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 100),
              
              // Loading
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
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
