import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../providers/user_provider.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.userName.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Support Center'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hey $userName,', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text(
                          'How can we help\nyou today?',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.headset_mic, color: AppColors.primary, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // FAQs
                const Text('Frequently Asked Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                _buildFAQItem(Icons.recycling, AppColors.primary, 'What waste types do you accept?'),
                _buildFAQItem(Icons.local_shipping, Colors.blue, 'My collector hasn\'t arrived yet'),
                _buildFAQItem(Icons.account_balance_wallet, AppColors.warning, 'How do I redeem my EcoPoints?'),
                _buildFAQItem(Icons.security, Colors.red, 'Is my account data secure?'),

                const SizedBox(height: 32),

                // Contact Methods
                const Text('Contact Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                
                _buildContactCard(
                  context,
                  'WhatsApp Support',
                  'Chat with our team instantly',
                  Icons.chat_bubble_outline,
                  const Color(0xFF25D366),
                  () => _showContactConfirmation(context, 'WhatsApp', '+254 700 000 000'),
                ),
                const SizedBox(height: 12),
                _buildContactCard(
                  context,
                  'Email Support',
                  'support@globalcoolers.co.ke',
                  Icons.email_outlined,
                   AppColors.primary,
                  () => _showContactConfirmation(context, 'Email', 'support@globalcoolers.co.ke'),
                ),

                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          if (index == 1) Navigator.pushNamed(context, '/schedule-pickup');
          if (index == 2) Navigator.pushNamed(context, '/rewards');
        },
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.1))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))])),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showContactConfirmation(BuildContext context, String method, String info) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening $method: $info'), backgroundColor: AppColors.primary));
  }

  Widget _buildFAQItem(IconData icon, Color color, String question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 14),
          Expanded(child: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }
}
