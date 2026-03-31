import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ActivityItem extends StatelessWidget {
  final String title;
  final String timestamp;
  final int points;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  const ActivityItem({
    super.key,
    required this.title,
    required this.timestamp,
    required this.points,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });

  /// Maps waste type names to their category colors & icons
  static Map<String, dynamic> wasteVisual(String wasteType) {
    final type = wasteType.toLowerCase();
    if (type.contains('organic')) return {'color': AppColors.organic, 'icon': Icons.compost_rounded};
    if (type.contains('plastic')) return {'color': AppColors.plastic, 'icon': Icons.local_drink_rounded};
    if (type.contains('paper')) return {'color': AppColors.paper, 'icon': Icons.newspaper_rounded};
    if (type.contains('metal')) return {'color': AppColors.metal, 'icon': Icons.settings_rounded};
    if (type.contains('glass')) return {'color': AppColors.glass, 'icon': Icons.wine_bar_rounded};
    if (type.contains('e-waste') || type.contains('ewaste')) return {'color': AppColors.ewaste, 'icon': Icons.devices_rounded};
    if (type.contains('hazard')) return {'color': AppColors.hazardous, 'icon': Icons.warning_amber_rounded};
    return {'color': AppColors.primary, 'icon': Icons.recycling_rounded};
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timestamp,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.15), AppColors.accent.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '+$points',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
