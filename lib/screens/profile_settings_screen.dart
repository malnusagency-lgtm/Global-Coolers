import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_localizations.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  int _currentIndex = 3; // Account tab

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) Navigator.pushNamed(context, '/home');
    if (index == 1) Navigator.pushNamed(context, '/schedule-pickup');
    if (index == 2) Navigator.pushNamed(context, '/rewards');
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final userProvider = context.watch<UserProvider>();
    final l10n = AppLocalizations.of(context);
    final isEnglish = localeProvider.locale.languageCode == 'en';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, size: 50, color: Colors.white),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userProvider.userName.isEmpty ? 'Jane Wanjiku' : userProvider.userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Account Profile',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Language Switch
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.language, color: Colors.blue),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Language / Lugha',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          isEnglish ? 'English' : 'Kiswahili',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Switch(
                          value: isEnglish,
                          onChanged: (val) {
                            localeProvider.toggleLocale();
                          },
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                'Account Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              _buildSettingItem(l10n.translate('edit_profile'), Icons.person_outline, () {}),
              _buildSettingItem(l10n.translate('my_address'), Icons.location_on_outlined, () {}),
              _buildSettingItem(l10n.translate('payment_methods'), Icons.credit_card, () {}),
              _buildSettingItem(l10n.translate('notifications'), Icons.notifications_none, () {}),
              
              const SizedBox(height: 24),
              Text(
                l10n.translate('help_support'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              
              _buildSettingItem(l10n.translate('help_support'), Icons.help_outline, () {
                 Navigator.pushNamed(context, '/support');
              }),
              _buildSettingItem(l10n.translate('privacy_policy'), Icons.lock_outline, () {}),
              _buildSettingItem(l10n.translate('log_out'), Icons.logout, () async {
                await userProvider.signOut();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/'); 
              }, isDestructive: true),
              
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }

  Widget _buildSettingItem(String title, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          // boxShadow: [
          //   BoxShadow(
          //     color: Colors.black.withOpacity(0.02),
          //     blurRadius: 5,
          //     offset: const Offset(0, 2),
          //   ),
          // ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? AppColors.error : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDestructive ? AppColors.error : AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
