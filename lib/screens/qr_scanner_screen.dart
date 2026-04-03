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

      // Show unified completion bottom sheet
      final double estimatedWeight = (pickup['weight_kg'] as num?)?.toDouble() ?? 1.0;
      _showCompletePickupSheet(pickup, estimatedWeight, code);

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

  void _showCompletePickupSheet(Map<String, dynamic> pickup, double estimatedWeight, String qrCode) {
    double actualWeight = estimatedWeight;
    bool paymentConfirmed = false;
    bool isLoading = false;
    final int originalCostKes = (pickup['cost_kes'] as num?)?.toInt() ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 48, height: 6, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 24),
                  
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Finalize Pickup', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            Text('Verify weight and confirm payment', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Weight Editor
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text('Actual Collected Weight', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 1.2)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle, size: 40, color: AppColors.primary),
                              onPressed: () {
                                if (actualWeight > 0.5) {
                                  setModalState(() => actualWeight -= 0.5);
                                  HapticFeedback.selectionClick();
                                }
                              },
                            ),
                            const SizedBox(width: 20),
                            Text('${actualWeight} kg', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: const Icon(Icons.add_circle, size: 40, color: AppColors.primary),
                              onPressed: () {
                                if (actualWeight < 500) {
                                  setModalState(() => actualWeight += 0.5);
                                  HapticFeedback.selectionClick();
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Checkbox
                  GestureDetector(
                    onTap: () => setModalState(() => paymentConfirmed = !paymentConfirmed),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: paymentConfirmed ? AppColors.success.withOpacity(0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: paymentConfirmed ? AppColors.success.withOpacity(0.3) : Colors.grey.shade300, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(paymentConfirmed ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: paymentConfirmed ? AppColors.success : Colors.grey, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Payment Received', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('Collected KES $originalCostKes from resident', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Points Preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _pointPreview('You (Collector)', (actualWeight * 10).round(), AppColors.primary),
                        Container(width: 1, height: 20, color: Colors.grey.withOpacity(0.2)),
                        _pointPreview('Resident', (actualWeight * 20).round(), AppColors.teal),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Action Buttons
                  if (isLoading)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: CircularProgressIndicator(color: AppColors.primary))
                  else
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() => _isScanning = true);
                            },
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: paymentConfirmed ? AppColors.primary : Colors.grey.shade300,
                              foregroundColor: Colors.white,
                              elevation: paymentConfirmed ? 8 : 0,
                              shadowColor: AppColors.primary.withOpacity(0.4),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: paymentConfirmed ? () async {
                              setModalState(() => isLoading = true);
                              try {
                                final residentPoints = (actualWeight * 20).round();
                                final collectorPoints = (actualWeight * 10).round();
                                
                                await _supabaseService.completePickup(
                                  pickupId: pickup['id'].toString(),
                                  qrCode: qrCode,
                                  actualWeightKg: actualWeight,
                                );
                                
                                // Refresh profile data in background
                                try {
                                  if (context.mounted) {
                                    final userProvider = Provider.of<UserProvider>(this.context, listen: false);
                                    userProvider.loadUserData();
                                  }
                                } catch (e) {
                                  debugPrint('Profile refresh failed: $e');
                                }
                                
                                if (!mounted) return;
                                Navigator.pop(ctx);
                                
                                Navigator.pushReplacementNamed(
                                  this.context,
                                  '/pickup-complete',
                                  arguments: {
                                    'residentName': pickup['profiles']?['full_name'] ?? 'Resident',
                                    'wasteType': pickup['waste_type'] ?? 'Waste',
                                    'collectorPoints': collectorPoints,
                                    'residentPoints': residentPoints,
                                    'weightKg': actualWeight,
                                    'costKes': originalCostKes,
                                    'pickupId': pickup['id'].toString(),
                                  },
                                );
                              } catch (e) {
                                setModalState(() => isLoading = false);
                                Navigator.pop(ctx);
                                _showErrorDialog('Completion Failed', e.toString().replaceAll('Exception: ', ''));
                              }
                            } : null,
                            child: const Text('Complete & Earn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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

  Widget _pointPreview(String label, int points, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.eco_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Text('+$points', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ],
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
