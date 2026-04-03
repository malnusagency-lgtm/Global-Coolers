import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_colors.dart';
import '../services/supabase_service.dart';

class PickupConfirmationScreen extends StatefulWidget {
  const PickupConfirmationScreen({super.key});

  @override
  State<PickupConfirmationScreen> createState() => _PickupConfirmationScreenState();
}

class _PickupConfirmationScreenState extends State<PickupConfirmationScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  StreamSubscription? _pickupSubscription;
  bool _isInit = false;
  String? _qrCode;
  String? _wasteType;
  double? _weightKg;
  int? _costKes;
  String? _pickupId;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _qrCode = args?['qrCode'] ?? 'no_code';
      _wasteType = args?['wasteType'] ?? 'General';
      _weightKg = (args?['weightKg'] as num?)?.toDouble() ?? 1.0;
      _costKes = (args?['costKes'] as num?)?.toInt() ?? 0;
      _pickupId = args?['pickupId']?.toString();
      
      if (_pickupId != null) {
        _startListening();
      }
      _isInit = true;
    }
  }

  void _startListening() {
    _pickupSubscription = _supabaseService.streamPickupStatus(_pickupId!).listen((status) {
      if (!mounted) return;
      
      // 1. Monitor for Acceptance
      if (status['status'] == 'accepted' || status['status'] == 'in_transit') {
        _showCollectionAcceptedDialog(status);
      }

      // 2. Monitor for Completion
      if (status['status'] == 'completed') {
        _pickupSubscription?.cancel();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        });
      }
    });
  }

  bool _isAlertShown = false;
  void _showCollectionAcceptedDialog(Map<String, dynamic> pickup) {
    if (!mounted || _isAlertShown) return;
    _isAlertShown = true;
    final collectorName = pickup['collector_name'] ?? 'A collector';
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.primaryGradient),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.celebration_rounded, color: Colors.white, size: 50),
                    SizedBox(height: 12),
                    Text('PICKUP CLAIMED!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      '$collectorName is coming to help!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your collection request for ${pickup['waste_type']} has been accepted. You can now track them live!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.pushNamed(context, '/live-tracking', arguments: {
                                'collectorId': pickup['collector_id'],
                                'pickupId': pickup['id'],
                                'qrCode': _qrCode,
                                'wasteType': _wasteType,
                                'weightKg': _weightKg,
                                'costKes': _costKes,
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('TRACK LIVE 🚛', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Got it', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pickupSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int pointsEarned = ((_weightKg ?? 1.0) * 20).round();

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
                    _buildSummaryItem(Icons.delete_outline_rounded, _wasteType ?? 'N/A', 'Type'),
                    Container(width: 1, height: 40, color: Colors.grey.shade200),
                    _buildSummaryItem(Icons.scale_rounded, '${_weightKg! % 1 == 0 ? _weightKg!.toInt() : _weightKg} kg', 'Weight'),
                    Container(width: 1, height: 40, color: Colors.grey.shade200),
                    _buildSummaryItem(Icons.payments_rounded, 'KES $_costKes', 'Cost'),
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
                      _qrCode ?? 'N/A',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    QrImageView(
                      data: _qrCode ?? 'no_code',
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
