import 'package:flutter/material.dart';

import '../../domain/waveform/waveform_peaks.dart';

/// Draws a song's waveform as vertical bars. [PRD FR-026, FR-032]
///
/// * Bars inside [startMs]..[endMs] are drawn in the accent colour, so the
///   selected loop region is obvious. Without a region, all bars look alike.
/// * [positionMs] draws a thin playhead line.
/// * [totalMs] is the time shown across the full width (the song length).
///
/// Display only; dragging handles comes in the next step.
class WaveformView extends StatelessWidget {
  const WaveformView({
    super.key,
    required this.peaks,
    required this.totalMs,
    this.startMs,
    this.endMs,
    this.positionMs,
    this.height = 96,
  });

  final WaveformPeaks peaks;
  final int totalMs;
  final int? startMs;
  final int? endMs;
  final int? positionMs;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Song waveform',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: LayoutBuilder(
              builder: (context, constraints) => CustomPaint(
                size: Size(constraints.maxWidth, height),
                painter: _WaveformPainter(
                  peaks: peaks,
                  totalMs: totalMs > 0 ? totalMs : peaks.durationMs,
                  startMs: startMs,
                  endMs: endMs,
                  positionMs: positionMs,
                  barColor: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                  regionColor: scheme.primary,
                  playheadColor: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.peaks,
    required this.totalMs,
    required this.startMs,
    required this.endMs,
    required this.positionMs,
    required this.barColor,
    required this.regionColor,
    required this.playheadColor,
  });

  final WaveformPeaks peaks;
  final int totalMs;
  final int? startMs;
  final int? endMs;
  final int? positionMs;
  final Color barColor;
  final Color regionColor;
  final Color playheadColor;

  static const double _barSlot = 3; // 2 px bar + 1 px gap

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || totalMs <= 0) return;

    final count = (size.width / _barSlot).floor().clamp(1, 4000).toInt();
    final bars = peaks.bars(count);
    final slot = size.width / count;
    final midY = size.height / 2;

    final barPaint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final s = startMs;
    final e = endMs;
    final hasRegion = s != null && e != null && s < e;

    for (var i = 0; i < count; i++) {
      final x = (i + 0.5) * slot;
      final timeMs = (i + 0.5) / count * totalMs;
      final inRegion = hasRegion && timeMs >= s && timeMs <= e;
      barPaint.color = inRegion ? regionColor : barColor;
      final half = (bars[i] * (size.height * 0.45)).clamp(1.0, size.height / 2);
      canvas.drawLine(Offset(x, midY - half), Offset(x, midY + half), barPaint);
    }

    final pos = positionMs;
    if (pos != null && pos >= 0) {
      final x = (pos / totalMs).clamp(0.0, 1.0) * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = playheadColor
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.peaks != peaks ||
      old.totalMs != totalMs ||
      old.startMs != startMs ||
      old.endMs != endMs ||
      old.positionMs != positionMs ||
      old.barColor != barColor ||
      old.regionColor != regionColor ||
      old.playheadColor != playheadColor;
}
