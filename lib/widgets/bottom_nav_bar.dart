import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/app_localizations.dart';

enum UserRole { resident, collector }

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final UserRole role;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.role = UserRole.resident,
  });

  List<_NavItem> _items(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (role) {
      case UserRole.resident:
        return [
          _NavItem(Icons.home_rounded, Icons.home_outlined, l10n.translate('nyumbani'), AppColors.primary),
          _NavItem(Icons.calendar_today_rounded, Icons.calendar_today_outlined, l10n.translate('ratiba'), AppColors.teal),
          _NavItem(Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, l10n.translate('tuzo'), AppColors.amber),
          _NavItem(Icons.person_rounded, Icons.person_outlined, l10n.translate('akaunti'), AppColors.indigo),
        ];
      case UserRole.collector:
        return [
          _NavItem(Icons.map_rounded, Icons.map_outlined, l10n.translate('njia'), AppColors.primary),
          _NavItem(Icons.history_rounded, Icons.history_outlined, l10n.translate('historia'), AppColors.teal),
          _NavItem(Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, l10n.translate('tuzo'), AppColors.amber),
          _NavItem(Icons.person_rounded, Icons.person_outlined, l10n.translate('akaunti'), AppColors.indigo),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items(context).length, (index) {
              final item = _items(context)[index];
              return _NavItemWidget(
                index: index,
                isSelected: currentIndex == index,
                activeIcon: item.activeIcon,
                inactiveIcon: item.inactiveIcon,
                label: item.label,
                activeColor: item.activeColor,
                onTap: () => onTap(index),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemWidget extends StatefulWidget {
  final int index;
  final bool isSelected;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.index,
    required this.isSelected,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.activeColor,
    required this.onTap,
  });

  @override
  State<_NavItemWidget> createState() => _NavItemWidgetState();
}

class _NavItemWidgetState extends State<_NavItemWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color inactiveColor = AppColors.textSecondary;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isSelected ? 18 : 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.activeColor.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isSelected ? widget.activeIcon : widget.inactiveIcon,
                color: widget.isSelected ? widget.activeColor : inactiveColor,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected ? widget.activeColor : inactiveColor,
                  fontSize: 11,
                  fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final Color activeColor;
  const _NavItem(this.activeIcon, this.inactiveIcon, this.label, this.activeColor);
}
