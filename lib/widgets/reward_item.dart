import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RewardItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final int points;
  final String imageAsset;
  final String? iconName;
  final String? colorHex;
  final VoidCallback onRedeem;
  final bool canAfford;

  const RewardItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.imageAsset,
    this.iconName,
    this.colorHex,
    required this.onRedeem,
    required this.canAfford,
  });

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primary;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  IconData _mapIcon(String? name) {
    switch (name) {
      case 'account_balance_wallet': return Icons.account_balance_wallet;
      case 'shopping_cart': return Icons.shopping_cart;
      case 'phone_android': return Icons.phone_android;
      case 'eco': return Icons.eco;
      case 'wb_sunny': return Icons.wb_sunny;
      default: return Icons.card_giftcard;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: _parseColor(colorHex).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Center(
              child: Icon(
                _mapIcon(iconName), 
                size: 44, 
                color: _parseColor(colorHex),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$points pts',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                    InkWell(
                      onTap: canAfford ? onRedeem : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: canAfford ? AppColors.primary : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Redeem',
                          style: TextStyle(
                            color: canAfford ? Colors.white : Colors.grey.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
