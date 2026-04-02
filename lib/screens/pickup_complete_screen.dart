import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../services/supabase_service.dart';

class PickupCompleteScreen extends StatefulWidget {
  const PickupCompleteScreen({super.key});

  @override
  State<PickupCompleteScreen> createState() => _PickupCompleteScreenState();
}

class _PickupCompleteScreenState extends State<PickupCompleteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  int _selectedRating = 0;
  bool _ratingSubmitted = false;
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    // Haptic feedback on success
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ?? {};
    final String residentName = args['residentName'] as String? ?? 'the Resident';
    final String wasteType = args['wasteType'] as String? ?? 'Mixed Waste';
    final int collectorPoints = args['collectorPoints'] as int? ?? 0;
    final int residentPoints = args['residentPoints'] as int? ?? 0;
    final double weightKg = (args['weightKg'] as num?)?.toDouble() ?? 0.0;
    final int costKes = args['costKes'] as int? ?? 0;
    final String? pickupId = args['pickupId'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FFF4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20),
          child: Column(
            children: [
              // ── Success Animation ──
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.success.withOpacity(0.18),
                        AppColors.success.withOpacity(0.05),
                        Colors.transparent,
                      ],
                      radius: 1.2,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 48),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'Pickup Complete!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                "Collected from $residentName",
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 32),

              // ── Earnings Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    const Text('YOUR EARNINGS', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.eco_rounded, color: AppColors.primary, size: 36),
                        const SizedBox(width: 8),
                        Text(
                          '+$collectorPoints',
                          style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const Text('Eco Points Earned', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Details
                    _detailRow(Icons.recycling_rounded, AppColors.primary, wasteType, '${weightKg % 1 == 0 ? weightKg.toInt() : weightKg} kg collected'),
                    const SizedBox(height: 12),
                    _detailRow(Icons.payments_rounded, AppColors.amber, 'Payment Received', 'KES $costKes'),
                    const SizedBox(height: 12),
                    _detailRow(Icons.person_rounded, AppColors.teal, "$residentName earned", '+$residentPoints pts'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Rating Section ──
              if (!_ratingSubmitted && pickupId != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
                  ),
                  child: Column(
                    children: [
                      const Text('Rate this Pickup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('How was the experience?', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          return GestureDetector(
                            onTap: () => setState(() => _selectedRating = i + 1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                i < _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: AppColors.amber,
                                size: 36,
                              ),
                            ),
                          );
                        }),
                      ),
                      if (_selectedRating > 0) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                await _supabaseService.submitRating(pickupId: pickupId, rating: _selectedRating);
                                if (mounted) setState(() => _ratingSubmitted = true);
                              } catch (_) {
                                if (mounted) setState(() => _ratingSubmitted = true);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.amber,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: const Text('Submit Rating', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              if (_ratingSubmitted)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.success),
                      SizedBox(width: 8),
                      Text('Thank you for your rating!', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

              const SizedBox(height: 28),

              // ── Actions ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Points awarded — go scan next
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/collector-dashboard',
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan Next Household'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/collector-dashboard', (route) => false),
                child: const Text('Back to Dashboard', style: TextStyle(color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, Color color, String title, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
