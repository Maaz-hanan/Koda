import 'package:flutter/material.dart';

import '../../domain/loop/loop_mode.dart';
import '../shared/glass_container.dart';
import '../theme/app_theme.dart';

/// The Loop button on the Now Playing screen. [PRD §3.1, §3.2, FR-042]
///
/// * Short tap  -> [onTap]       (cycles Off / Once / Infinite)
/// * Long press -> [onLongPress] (opens the custom loop editor)
///
/// Flutter's tap detector never fires a tap after a long press has been
/// recognised, so a long press cannot also trigger the tap cycle.
class LoopButton extends StatelessWidget {
  const LoopButton({
    super.key,
    required this.mode,
    required this.onTap,
    required this.onLongPress,
  });

  final LoopMode mode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  String get _label {
    switch (mode) {
      case LoopMode.off:
        return 'Repeat off';
      case LoopMode.repeatOnce:
        return 'Repeat once';
      case LoopMode.repeatInfinite:
        return 'Repeat forever';
      case LoopMode.finiteSection:
        return 'Section loop, limited repeats';
      case LoopMode.infiniteSection:
        return 'Section loop, repeats forever';
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = mode != LoopMode.off;
    final color = active ? AppColors.accent : AppColors.textSecondary;

    return Semantics(
      button: true,
      label: _label,
      hint: 'Tap to change repeat mode. Touch and hold for custom loop.',
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      // No Tooltip here: its own long-press handler would compete with ours.
      child: Material(
        type: MaterialType.transparency,
        child: InkResponse(
          onTap: onTap,
          onLongPress: onLongPress,
          radius: 28,
          child: SizedBox(
            width: 56, // comfortably above the 48 pt minimum touch target
            height: 56,
            child: Center(
              child: SizedBox(
                width: AppSpacing.minTouchTarget,
                height: AppSpacing.minTouchTarget,
                child: GlassContainer(
                  radius: AppSpacing.minTouchTarget / 2,
                  fill: active
                      ? AppColors.glassFillStrong
                      : AppColors.glassFill,
                  child: Center(child: _icon(color)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _icon(Color color) {
    switch (mode) {
      case LoopMode.off:
        return Icon(Icons.repeat, size: 24, color: color);
      case LoopMode.repeatOnce:
        // Material's repeat_one icon is the repeat arrows with a "1".
        return Icon(Icons.repeat_one, size: 24, color: color);
      case LoopMode.repeatInfinite:
        return _badged(color, '∞');
      case LoopMode.finiteSection:
      case LoopMode.infiniteSection:
        // Temporary look until Phase 3 builds the real section loop.
        return _badged(color, 'A-B');
    }
  }

  Widget _badged(Color color, String badge) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Icon(Icons.repeat, size: 24, color: color),
        Positioned(
          right: -5,
          bottom: -5,
          child: Text(
            badge,
            style: TextStyle(
              color: color,
              fontSize: badge.length > 1 ? 10 : 16,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}
