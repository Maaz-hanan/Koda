import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A frosted-glass panel, our approximation of Apple's "Liquid Glass":
/// the content behind it is blurred, then a translucent white fill, a faint
/// light-to-dark highlight and a hairline border are added.
///
/// Blurring is expensive, so use it only on a few things: the mini player,
/// bottom sheets, and small round buttons. NEVER on every row of a list.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.radius = AppRadius.glassMiniPlayer,
    this.fill = AppColors.glassFill,
    this.blur = 24,
    this.padding,
    this.shadow = false,
  });

  final Widget child;

  /// Corner radius. For a circle use half the size (or any big number).
  final double radius;

  /// The translucent fill color on top of the blur.
  final Color fill;

  /// Blur strength (sigma).
  final double blur;

  final EdgeInsetsGeometry? padding;

  /// A soft drop shadow underneath (the floating mini player uses it).
  final bool shadow;

  static const _highlight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color.fromRGBO(255, 255, 255, 0.10), Color.fromRGBO(255, 255, 255, 0.02)],
  );

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    Widget glass = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            gradient: _highlight,
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          child: padding == null ? child : Padding(padding: padding!, child: child),
        ),
      ),
    );

    if (shadow) {
      glass = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.25),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: glass,
      );
    }
    return glass;
  }
}
