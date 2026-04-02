import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';
import '../services/supabase_service.dart';
import 'package:latlong2/latlong.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with TickerProviderStateMixin {
  bool _isScanning = true;
  final SupabaseService _supabaseService = SupabaseService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.startsWith('GC-')) {
        setState(() => _isScanning = false);
        _verifyCode(code);
      } else if (code != null) {
        // Non-Global Coolers QR code
        setState(() => _isScanning = false);
        _showErrorDialog('Invalid QR Code', 'This QR code is not a valid Global Coolers pickup tag. Please scan the code shown on the resident\'s phone.');
      }
    }
  }

  Future<void> _verifyCode(String code) async {
    try {
      // Show loading overlay
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text('Verifying pickup...', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ),
      );

      final pickup = await _supabaseService.verifyPickupByQr(code);

      // Geo-fencing verification
      final pickupLat = (pickup['latitude'] as num?)?.toDouble();
      final pickupLng = (pickup['longitude'] as num?)?.toDouble();

      if (pickupLat != null && pickupLng != null) {
        final currentPos = await _supabaseService.getCurrentPosition();
        if (currentPos != null) {
          final currentLatLng = LatLng(currentPos.latitude, currentPos.longitude);
          final targetLatLng = LatLng(pickupLat, pickupLng);
          final distance = const Distance().as(LengthUnit.Meter, currentLatLng, targetLatLng);

          if (distance > 150) {
            if (!mounted) return;
            Navigator.pop(context); // Pop loading
            _showErrorDialog('Verification Failed', 'You are too far from the pickup location to scan this QR code. Please move closer.');
            return;
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Pop loading

      // Show bottom sheet to verify actual weight
      final double estimatedWeight = (pickup['weight_kg'] as num?)?.toDouble() ?? 1.0;
      _showWeightVerificationSheet(pickup, estimatedWeight, code);

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Pop loading

      String errorTitle = 'Verification Failed';
      String errorMessage = e.toString().replaceAll('Exception: ', '');

      if (errorMessage.contains('already been verified')) {
        errorTitle = 'Already Verified';
        errorMessage = 'This pickup has already been completed and points were awarded.';
      } else if (errorMessage.contains('No rows')) {
        errorTitle = 'Pickup Not Found';
        errorMessage = 'No scheduled pickup matches this QR code. It may have been cancelled.';
      }

      _showErrorDialog(errorTitle, errorMessage);
    }
  }

  void _showWeightVerificationSheet(Map<String, dynamic> pickup, double estimatedWeight, String qrCode) {
    double actualWeight = estimatedWeight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  const Text('Verify Pickup Weight', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('Resident estimated ${estimatedWeight}kg. Please confirm the actual physical weight collected.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 32, color: AppColors.primary),
                        onPressed: () {
                          if (actualWeight > 0.5) setModalState(() => actualWeight -= 0.5);
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                        child: Text('${actualWeight} kg', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 32, color: AppColors.primary),
                        onPressed: () {
                          if (actualWeight < 50) setModalState(() => actualWeight += 0.5);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _finalizePickupWithWeight(pickup, actualWeight, qrCode);
                      },
                      child: const Text('Confirm & Complete', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _finalizePickupWithWeight(Map<String, dynamic> pickup, double confirmedWeightKg, String qrCode) async {
    // Step 1: Payment Confirmation
    final bool? paymentConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.payments_rounded, color: AppColors.amber),
            SizedBox(width: 8),
            Text('Confirm Payment'),
          ],
        ),
        content: Text('Have you received the payment of KES ${pickup['cost_kes'] ?? 0} from ${pickup['profiles']?['full_name'] ?? 'the resident'}?\n\nPoints will be awarded to both of you only after you confirm receipt of payment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not Yet', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yes, Payment Received', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (paymentConfirmed != true) return;

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );

      // Re-calculate based on confirmed weight
      final int originalCostKes = (pickup['cost_kes'] as num?)?.toInt() ?? 0;
      final int residentPoints = (confirmedWeightKg * 20).round();
      final int collectorPoints = (confirmedWeightKg * 10).round();

      await _supabaseService.completePickup(
        pickupId: pickup['id'].toString(),
        qrCode: qrCode,
        actualWeightKg: confirmedWeightKg,
      );

      if (!mounted) return;
      Navigator.pop(context); // Pop loading

      _showSuccessDialog(
        residentName: pickup['profiles']?['full_name'] ?? 'Resident',
        wasteType: pickup['waste_type'] ?? 'Waste',
        pointsAwarded: collectorPoints,
        residentPoints: residentPoints,
        weightKg: confirmedWeightKg,
        costKes: originalCostKes,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Pop loading
      _showErrorDialog('Completion Failed', e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showSuccessDialog({
    required String residentName,
    required String wasteType,
    required int pointsAwarded,
    int residentPoints = 0,
    double weightKg = 1.0,
    int costKes = 0,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated checkmark
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppColors.success, size: 56),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pickup Verified! 🎉',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                '$residentName\'s $wasteType pickup (${weightKg % 1 == 0 ? weightKg.toInt() : weightKg}kg) completed.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // Earnings breakdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _earningsRow('Pickup Value', 'KES $costKes', AppColors.textPrimary),
                    const SizedBox(height: 10),
                    _earningsRow('Your Earnings', '+$pointsAwarded pts', AppColors.primary),
                    const SizedBox(height: 10),
                    _earningsRow('Resident Earned', '+$residentPoints pts', AppColors.teal),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Your points chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '+$pointsAwarded EcoPoints Earned!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _isScanning = true);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Scan Another', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context); // Back to dashboard
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pushReplacementNamed(context, '/rewards');
                  },
                  icon: const Icon(Icons.card_giftcard_rounded, color: AppColors.primary, size: 20),
                  label: const Text('Explore Rewards', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.primary.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),

      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline, color: Colors.red.shade400, size: 56),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _isScanning = true);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            onDetect: _onDetect,
          ),

          // Dark scan overlay with center cutout effect
          Container(
            color: Colors.black.withOpacity(0.5),
          ),

          // Scanner frame
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 4),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isScanning ? Icons.qr_code_scanner : Icons.hourglass_top,
                      color: Colors.white.withOpacity(0.8),
                      size: 48,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isScanning ? AppColors.primary : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isScanning ? '● SCANNING' : '● PROCESSING',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Bottom instructions
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Align the Resident\'s QR code within the frame',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _earningsRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }
}
