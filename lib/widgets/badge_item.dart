import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BadgeItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isLocked;

  const BadgeItem({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: isLocked ? Colors.grey.shade200 : color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: isLocked ? Colors.transparent : color,
              width: 2,
            ),
          ),
          child: Icon(
            isLocked ? Icons.lock : icon,
            color: isLocked ? Colors.grey : color,
            size: 32,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isLocked ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
