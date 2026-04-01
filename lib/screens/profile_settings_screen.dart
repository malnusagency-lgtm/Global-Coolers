import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_localizations.dart';
import '../services/api_service.dart';
import './privacy_policy_screen.dart';


class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  int _currentIndex = 3; // Account tab

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    final userProvider = context.read<UserProvider>();
    
    if (userProvider.isCollector) {
      if (index == 0) Navigator.pushNamed(context, '/collector-dashboard');
      if (index == 2) Navigator.pushNamed(context, '/profile');
    } else {
      if (index == 0) Navigator.pushNamed(context, '/home');
      if (index == 1) Navigator.pushNamed(context, '/schedule-pickup');
      if (index == 2) Navigator.pushNamed(context, '/rewards');
    }
  }


  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final l10n = AppLocalizations.of(context);

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
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: AppColors.primaryGradient),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: AppColors.primary.withOpacity(0.08),
                              child: Text(
                                userProvider.userName.isNotEmpty ? userProvider.userName[0].toUpperCase() : 'G',
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: AppColors.primaryGradient),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userProvider.userName.isEmpty ? 'Guest' : userProvider.userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        userProvider.phone.isNotEmpty ? userProvider.phone : userProvider.email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              const Text(
                'Account Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 14),
              
              _buildSettingItem(l10n.translate('edit_profile'), Icons.person_outline_rounded, AppColors.indigo, () {
                _showEditProfileDialog(context, userProvider);
              }),
              
              if (!userProvider.isCollector) ...[
                _buildSettingItem(l10n.translate('my_address'), Icons.location_on_outlined, AppColors.teal, () {
                  Navigator.pushNamed(context, '/my-address');
                }),
                _buildSettingItem(l10n.translate('payment_methods'), Icons.credit_card_rounded, AppColors.amber, () {
                  Navigator.pushNamed(context, '/payment-methods');
                }),
              ],

              _buildSettingItem(l10n.translate('notifications'), Icons.notifications_none_rounded, AppColors.primary, () {
                Navigator.pushNamed(context, '/notifications');
              }),
              
              const SizedBox(height: 24),
              Text(
                l10n.translate('help_support'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              
              _buildSettingItem(l10n.translate('help_support'), Icons.help_outline_rounded, AppColors.info, () {
                 Navigator.pushNamed(context, '/support');
              }),
              _buildSettingItem(l10n.translate('privacy_policy'), Icons.lock_outline_rounded, AppColors.purple, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                );
              }),

              _buildSettingItem('Clear History', Icons.delete_sweep_rounded, AppColors.amber, () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Clear History?'),
                    content: const Text('This will hide all completed pickups from your activity log. This action cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear', style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    await SupabaseService().clearUserHistory();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('History cleared! ✨'), backgroundColor: AppColors.success),
                      );
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }),

              _buildSettingItem(l10n.translate('log_out'), Icons.logout_rounded, AppColors.error, () async {
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
        currentIndex: userProvider.isCollector ? 2 : 3,
        role: userProvider.isCollector ? UserRole.collector : UserRole.resident,
        onTap: _onNavTap,
      ),

    );
  }

  Widget _buildSettingItem(String title, IconData icon, Color iconColor, VoidCallback onTap, {bool isDestructive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDestructive ? AppColors.error : iconColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isDestructive ? AppColors.error : iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
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
              Icons.chevron_right_rounded,
              color: Colors.grey.shade300,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, UserProvider provider) {
    final nameController = TextEditingController(text: provider.userName);
    final phoneController = TextEditingController(text: provider.phone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit_rounded, color: AppColors.indigo, size: 22),
            const SizedBox(width: 8),
            const Text('Edit Profile'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_rounded, color: AppColors.indigo, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number (e.g. +254...)',
                prefixIcon: Icon(Icons.phone_rounded, color: AppColors.teal, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await ApiService.updateProfile(
                userId: provider.userId,
                fullName: nameController.text.trim(),
                phone: phoneController.text.trim(),
              );

              if (success && ctx.mounted) {
                Navigator.pop(ctx);
                await provider.loadUserData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated! ✅'), backgroundColor: AppColors.success),
                  );
                }
              } else if (ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile.')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
