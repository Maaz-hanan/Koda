import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_container.dart';

/// A round glass button with one icon (44 pt). Used for the heart, queue,
/// shuffle, +/- nudges and similar small actions.
/// Off = white icon. [active] = stronger glass and an accent-colored icon.
/// A null [onPressed] shows it greyed out.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
    this.size = AppSpacing.minTouchTarget,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? AppColors.textTertiary
        : active
            ? AppColors.accent
            : AppColors.textPrimary;

    return SizedBox(
      width: size,
      height: size,
      child: GlassContainer(
        radius: size / 2,
        fill: active ? AppColors.glassFillStrong : AppColors.glassFill,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: iconSize,
          tooltip: tooltip,
          icon: Icon(icon, color: color),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
