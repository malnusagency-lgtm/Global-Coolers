import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class ImpactStatsScreen extends StatefulWidget {
  const ImpactStatsScreen({super.key});

  @override
  State<ImpactStatsScreen> createState() => _ImpactStatsScreenState();
}

class _ImpactStatsScreenState extends State<ImpactStatsScreen> {
  int _selectedPeriod = 1; // 0=Week, 1=Month, 2=Year

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final totalWaste = userProvider.totalWasteDiverted > 0 ? userProvider.totalWasteDiverted : 0;
    final treesSaved = (totalWaste / 21).toStringAsFixed(1);
    final co2Reduced = totalWaste.toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Impact Stats'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  _buildPeriodTab('Week', 0),
                  _buildPeriodTab('Month', 1),
                  _buildPeriodTab('Year', 2),
                ],
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              'Your Green Footprint',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Detailed analysis of your recycling habits in Nairobi.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),

            const SizedBox(height: 24),

            // Total Waste Diverted Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL WASTE DIVERTED', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                      Icon(Icons.info_outline, color: Colors.grey.shade400, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$totalWaste', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1)),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('kg', style: TextStyle(fontSize: 20, color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.trending_up, color: AppColors.success, size: 14),
                            const SizedBox(width: 2),
                            const Text('Live', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Simple chart visualization
                  SizedBox(
                    height: 120,
                    child: CustomPaint(
                      painter: _ChartPainter(),
                      size: const Size(double.infinity, 120),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['W1', 'W2', 'W3', 'W4'].map((w) => Text(w, style: TextStyle(color: AppColors.textSecondary, fontSize: 12))).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Global Impact Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2E1A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.public, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Global Impact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('You vs. Nairobi Goal', style: TextStyle(color: Colors.white60, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text((totalWaste > 0 ? (totalWaste * 0.01).toStringAsFixed(2) : '0.0'), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, height: 1)),
                      const Text('%', style: TextStyle(color: Colors.white60, fontSize: 20)),
                      const Spacer(),
                      const Text('of city goal', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.3,
                      backgroundColor: Colors.white24,
                      color: AppColors.accent,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Together, Nairobi has saved 50 tons of waste this month.\nYour contribution matters!',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Waste Breakdown
            Row(
              children: [
                Expanded(child: _buildWasteBreakdownCard('PLASTIC', '${(totalWaste * 0.4).toStringAsFixed(1)} kg', Icons.recycling, Colors.blue)),
                const SizedBox(width: 16),
                Expanded(child: _buildWasteBreakdownCard('ORGANIC', '${(totalWaste * 0.6).toStringAsFixed(1)} kg', Icons.eco, Colors.orange)),
              ],
            ),

            const SizedBox(height: 24),

            // Environmental Metrics
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  _buildEnvMetric(Icons.park, AppColors.primary, 'Trees Saved', 'Equivalent impact', treesSaved),
                  const Divider(height: 24),
                  _buildEnvMetric(Icons.cloud_off, Colors.blueGrey, 'CO2 Reduced', 'Emissions prevented', '$co2Reduced kg'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Share Button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2E1A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          if (index == 1) Navigator.pushNamed(context, '/schedule-pickup');
          if (index == 3) Navigator.pushNamed(context, '/profile');
        },
      ),
    );
  }

  Widget _buildPeriodTab(String label, int index) {
    final isSelected = _selectedPeriod == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWasteBreakdownCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Container(height: 4, width: 40, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _buildEnvMetric(IconData icon, Color color, String title, String subtitle, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.cubicTo(size.width * 0.15, size.height * 0.5, size.width * 0.25, size.height * 0.3, size.width * 0.35, size.height * 0.4);
    path.cubicTo(size.width * 0.45, size.height * 0.5, size.width * 0.55, size.height * 0.15, size.width * 0.65, size.height * 0.2);
    path.cubicTo(size.width * 0.75, size.height * 0.25, size.width * 0.85, size.height * 0.1, size.width, size.height * 0.3);

    canvas.drawPath(path, paint);

    // Draw dot at the peak
    final dotPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.2), 5, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.2), 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
