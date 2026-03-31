import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(Icons.security_rounded, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Introduction',
              'Welcome to Global Coolers. We are committed to protecting your personal information and your right to privacy. If you have any questions or concerns about our policy, or our practices with regards to your personal information, please contact us.',
            ),
            _buildSection(
              '2. Information We Collect',
              'We collect personal information that you provide to us such as name, address, contact information (email/phone), and environmental data (waste weight/type). For Collectors, we also collect real-time location data to facilitate pickups.',
            ),
            _buildSection(
              '3. How We Use Your Information',
              'We use the information we collect or receive to:\n• Facilitate account creation and logon process.\n• Request and fulfill waste pickups.\n• Award and redeem EcoPoints.\n• Improve our services and user experience.',
            ),
            _buildSection(
              '4. Location Data',
              'For our Collector partners, Global Coolers collects location data to enable nearby pickup detection even when the app is in the background or not in use, provided you are "Online". This is essential for the core functionality of the service.',
            ),
            _buildSection(
              '5. M-Pesa & Financial Data',
              'We only collect M-Pesa numbers for the purpose of processing reward redemptions. We do not store full credit card information on our servers; all payments are processed through secure third-party gateways.',
            ),
            _buildSection(
              '6. Contact Us',
              'If you have questions about this policy, you can email us at support@globalcoolers.com or reach out via the Support tab in the app.',
            ),
            const SizedBox(height: 40),
            const Center(
              child: Text(
                'Last Updated: March 2026',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
