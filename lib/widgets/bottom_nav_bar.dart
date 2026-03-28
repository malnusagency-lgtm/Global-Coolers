import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/app_localizations.dart';

enum UserRole { resident, collector }

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final UserRole role;

  const BottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.role = UserRole.resident,
  }) : super(key: key);

  List<_NavItem> _items(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (role) {
      case UserRole.resident:
        return [
          _NavItem(Icons.home_rounded, l10n.translate('nyumbani')),
          _NavItem(Icons.calendar_today_rounded, l10n.translate('ratiba')),
          _NavItem(Icons.account_balance_wallet_rounded, l10n.translate('tuzo')),
          _NavItem(Icons.person_rounded, l10n.translate('akaunti')),
        ];
      case UserRole.collector:
        return [
          _NavItem(Icons.map_rounded, l10n.translate('njia')),
          _NavItem(Icons.history_rounded, l10n.translate('historia')),
          _NavItem(Icons.person_rounded, l10n.translate('akaunti')),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items(context).length, (index) {
              return _buildNavItem(index, _items(context)[index].icon, _items(context)[index].label);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = currentIndex == index;
    final Color inactiveColor = AppColors.textSecondary;
    final Color activeColor = AppColors.primary;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
