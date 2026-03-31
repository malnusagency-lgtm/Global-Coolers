import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_colors.dart';

class PickupConfirmationScreen extends StatelessWidget {
  const PickupConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String qrCode = args?['qrCode'] ?? 'no_code';
    final String wasteType = args?['wasteType'] ?? 'General';
    final double weightKg = (args?['weightKg'] as num?)?.toDouble() ?? 1.0;
    final int costKes = (args?['costKes'] as num?)?.toInt() ?? 0;
    final int pointsEarned = (weightKg * 20).round();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Confirmation'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppColors.success, size: 56),
              ),
              const SizedBox(height: 20),
              const Text(
                'Pickup Scheduled!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Show this QR code to the collector when they arrive.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              
              const SizedBox(height: 24),

              // Cost Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(Icons.delete_outline_rounded, wasteType, 'Type'),
                    Container(width: 1, height: 40, color: Colors.grey.shade200),
                    _buildSummaryItem(Icons.scale_rounded, '${weightKg % 1 == 0 ? weightKg.toInt() : weightKg} kg', 'Weight'),
                    Container(width: 1, height: 40, color: Colors.grey.shade200),
                    _buildSummaryItem(Icons.payments_rounded, 'KES $costKes', 'Cost'),
                    Container(width: 1, height: 40, color: Colors.grey.shade200),
                    _buildSummaryItem(Icons.stars_rounded, '+$pointsEarned', 'Points'),
                  ],
                ),
              ),

              const Spacer(),
              
              // QR Code Card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Verification Code',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      qrCode,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    QrImageView(
                      data: qrCode,
                      version: QrVersions.auto,
                      size: 180.0,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.textPrimary,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false),
                  child: const Text('Back to Home'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
