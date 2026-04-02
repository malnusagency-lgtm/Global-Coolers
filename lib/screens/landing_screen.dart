import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF1A2E1A), // Brand dark green
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section
            Container(
              height: size.height * 0.65,
              width: double.infinity,
              child: Stack(
                children: [
                  // Real Background Image
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/landing_bg.jpeg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(color: AppColors.primaryDark),
                    ),
                  ),
                  // Gradient Overlay for readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            const Color(0xFF1A2E1A).withOpacity(0.9),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  Positioned(
                    top: 16,
                    right: 16,
                    child: SafeArea(
                      child: Consumer<LocaleProvider>(
                        builder: (context, localeProvider, child) {
                          final isEnglish = localeProvider.locale.languageCode == 'en';
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextButton(
                              onPressed: () => localeProvider.toggleLocale(),
                              child: Text(
                                isEnglish ? 'SW' : 'EN',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 60),
                        // New Branded Header
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset('assets/images/leaf_logo.png', height: 32),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'GLOBAL COOLERS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'SMARTER WASTE MANAGEMENT',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n.translate('landing_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.translate('landing_subtitle'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pushNamed(context, '/create-account'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 8,
                              shadowColor: AppColors.primary.withOpacity(0.4),
                            ),
                            child: Text(
                              l10n.translate('get_started'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // "How it Works" Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
              color: Colors.white,
              child: Column(
                children: [
                  Text(
                    l10n.translate('how_it_works'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildStep(l10n, 'step1_title', 'step1_desc', Icons.auto_delete_outlined),
                  _buildStep(l10n, 'step2_title', 'step2_desc', Icons.trending_up),
                  _buildStep(l10n, 'step3_title', 'step3_desc', Icons.redeem),
                ],
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(40),
              color: const Color(0xFF1A2E1A),
              child: Column(
                children: [
                  const Text('© 2026 Global Coolers Kenya', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(l10n.translate('slogan'), style: const TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(AppLocalizations l10n, String titleKey, String descKey, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: AppColors.primary, size: 32),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.translate(titleKey), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text(l10n.translate(descKey), style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
