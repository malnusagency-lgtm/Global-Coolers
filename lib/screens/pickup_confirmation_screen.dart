import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_colors.dart';

class PickupConfirmationScreen extends StatelessWidget {
  const PickupConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // In a real app, arguments would pass the qrCode and pickup details
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String qrCode = args?['qrCode'] ?? 'no_code';
    final String wasteType = args?['wasteType'] ?? 'General';

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
              const SizedBox(height: 20),
              const Icon(Icons.check_circle, color: AppColors.primary, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Pickup Scheduled!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                'A collector will arrive today for your $wasteType waste.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              
              const Spacer(),
              
              // QR Code Card
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Verification Code',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Show this to the collector upon arrival',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    QrImageView(
                      data: qrCode,
                      version: QrVersions.auto,
                      size: 200.0,
                      foregroundColor: AppColors.textPrimary,
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
