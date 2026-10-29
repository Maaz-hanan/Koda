import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bar heights (each between 0.2 and 1.0) at time [t] of the repeating
/// animation (t = 0..1, then it starts over). Every bar has its own phase and
/// every second bar moves twice as fast, so they dance independently.
/// Pure, so it is tested.
List<double> equalizerBarHeights(double t, {int bars = 4}) {
  const minHeight = 0.2;
  return [
    for (var i = 0; i < bars; i++)
      minHeight +
          (1 - minHeight) *
              (0.5 +
                  0.5 *
                      math.sin(2 * math.pi * (t * (1 + i % 2) + i * 0.27))),
  ];
}

/// The "now playing" bars: they move while [animating] is true (music is
/// playing) and rest in a fixed pose when it is false (paused). They also stay
/// still if the phone's "Reduce Motion" setting is on. Same size as a normal
/// 24-point icon, so it lines up with other icons.
class EqualizerIcon extends StatefulWidget {
  const EqualizerIcon({
    super.key,
    required this.animating,
    this.color,
    this.size = 24,
  });

  final bool animating;
  final Color? color;
  final double size;

  @override
  State<EqualizerIcon> createState() => _EqualizerIconState();
}

class _EqualizerIconState extends State<EqualizerIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _reduceMotion = false;

  bool get _shouldRun => widget.animating && !_reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(EqualizerIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_shouldRun) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: widget.animating ? 'Now playing' : 'Paused',
      child: ExcludeSemantics(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _EqualizerPainter(
              animation: _controller,
              color: color,
              animate: _shouldRun,
            ),
          ),
        ),
      ),
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  _EqualizerPainter({
    required this.animation,
    required this.color,
    required this.animate,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final bool animate;

  static const _restingPose = [0.35, 0.7, 0.5, 0.6];

  @override
  void paint(Canvas canvas, Size size) {
    final heights =
        animate ? equalizerBarHeights(animation.value) : _restingPose;
    final bars = heights.length;
    final gap = size.width * 0.12;
    final barWidth = (size.width - gap * (bars - 1)) / bars;
    final paint = Paint()..color = color;

    for (var i = 0; i < bars; i++) {
      final h = heights[i] * size.height;
      final left = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - h, barWidth, h),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter old) =>
      old.color != color || old.animate != animate;
}
