import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
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

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      try {
        final userProvider = context.read<UserProvider>();
        
        // Wait for data to be fully loaded (including background fetch)
        await userProvider.loadUserData().timeout(const Duration(seconds: 10));
        
        // Wait specifically for the flag if loadUserData returned early (e.g. from cache)
        // but we want to be absolutely sure the role is correct.
        if (!userProvider.isDataLoaded) {
          int retry = 0;
          while (!userProvider.isDataLoaded && retry < 20) { // 2s max more
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Centered Logo with Green Leaf
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(height: 32),
            
            // Brand Name
            const Text(
              'GLOBAL COOLERS',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'SMARTER WASTE • CLEANER FUTURE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: AppColors.primary.withOpacity(0.7),
              ),
            ),
            
            const SizedBox(height: 64),
            
            // Loading
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
