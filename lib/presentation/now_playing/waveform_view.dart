import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/loop_time.dart';
import '../../domain/loop/loop_region.dart';
import '../../domain/waveform/waveform_peaks.dart';
import '../theme/app_theme.dart';

enum _Handle { start, end }

/// Draws a song's waveform as vertical bars. [PRD FR-026, FR-027, FR-032]
///
/// * Bars inside [startMs]..[endMs] are drawn in the accent colour, so the
///   selected loop region is obvious.
/// * [positionMs] draws a thin playhead line.
/// * [totalMs] is the time shown across the full width (the song length).
///
/// If [onStartChanged] AND [onEndChanged] are given (and both [startMs] and
/// [endMs] are known), a green Start handle and a red End handle appear with
/// time labels, and they can be dragged. This widget only REPORTS the wanted
/// time (snapped to 10 ms); the owner decides what is allowed (see
/// LoopRegion) and passes the result back in as [startMs] / [endMs].
class WaveformView extends StatefulWidget {
  const WaveformView({
    super.key,
    required this.peaks,
    required this.totalMs,
    this.startMs,
    this.endMs,
    this.positionMs,
    this.onStartChanged,
    this.onEndChanged,
    this.height = 96,
  });

  final WaveformPeaks peaks;
  final int totalMs;
  final int? startMs;
  final int? endMs;
  final int? positionMs;
  final ValueChanged<int>? onStartChanged;
  final ValueChanged<int>? onEndChanged;
  final double height;

  @override
  State<WaveformView> createState() => _WaveformViewState();
}

class _WaveformViewState extends State<WaveformView> {
  /// How close (in pixels) a finger must be to grab a handle.
  static const double _grabRadius = 28;
  static const double _labelHeight = 22;
  static const double _labelWidth = 64;

  static const Color _startColor = Color(0xFF2E9E4F); // green
  static const Color _endColor = Color(0xFFD64545); // red

  _Handle? _active;

  /// Finger position minus handle position at the moment of grabbing, so the
  /// handle does not jump under the finger.
  double _grabOffset = 0;

  /// True when both handles were at the same spot when grabbed; the first
  /// movement direction then decides which one moves.
  bool _undecided = false;

  bool get _editable =>
      widget.onStartChanged != null &&
      widget.onEndChanged != null &&
      widget.startMs != null &&
      widget.endMs != null;

  int get _total =>
      widget.totalMs > 0 ? widget.totalMs : widget.peaks.durationMs;

  double _xOf(int ms, double width) =>
      _total <= 0 ? 0 : (ms / _total).clamp(0.0, 1.0).toDouble() * width;

  int _msOf(double x, double width) => (width <= 0 || _total <= 0)
      ? 0
      : ((x / width).clamp(0.0, 1.0).toDouble() * _total).round();

  void _onDragStart(DragStartDetails d, double width) {
    final s = widget.startMs;
    final e = widget.endMs;
    if (!_editable || s == null || e == null) return;

    final x = d.localPosition.dx;
    final xs = _xOf(s, width);
    final xe = _xOf(e, width);
    final ds = (x - xs).abs();
    final de = (x - xe).abs();

    if (ds > _grabRadius && de > _grabRadius) {
      _active = null; // finger is not near either handle
      return;
    }
    Haptics.tick(); // handle grabbed
    setState(() {
      _undecided = (ds - de).abs() < 2;
      _active = (ds <= de) ? _Handle.start : _Handle.end;
      _grabOffset = x - (_active == _Handle.start ? xs : xe);
    });
  }

  void _onDragUpdate(DragUpdateDetails d, double width) {
    if (_active == null) return;
    if (_undecided) {
      if (d.delta.dx == 0) return;
      setState(() {
        _active = d.delta.dx > 0 ? _Handle.end : _Handle.start;
        _undecided = false;
      });
    }
    final ms = LoopRegion.snap(_msOf(d.localPosition.dx - _grabOffset, width));
    if (_active == _Handle.start) {
      widget.onStartChanged?.call(ms);
    } else {
      widget.onEndChanged?.call(ms);
    }
  }

  void _onDragEnd() {
    if (_active == null) return;
    setState(() {
      _active = null;
      _undecided = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editable = _editable;

    return Semantics(
      label: editable
          ? 'Song waveform with loop start and end handles'
          : 'Song waveform',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final s = widget.startMs;
          final e = widget.endMs;

          final wave = SizedBox(
            height: widget.height,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: AppColors.glassFill,
                child: CustomPaint(
                  size: Size(width, widget.height),
                  painter: _WaveformPainter(
                    peaks: widget.peaks,
                    totalMs: _total,
                    startMs: widget.startMs,
                    endMs: widget.endMs,
                    positionMs: widget.positionMs,
                    showHandles: editable,
                    startActive: _active == _Handle.start,
                    endActive: _active == _Handle.end,
                    barColor: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                    regionColor: AppColors.accent,
                    playheadColor: scheme.onSurface,
                    startHandleColor: _startColor,
                    endHandleColor: _endColor,
                  ),
                ),
              ),
            ),
          );

          if (!editable || s == null || e == null) return wave;

          final labelStyle = TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          );
          final maxLeft = (width - _labelWidth).clamp(0.0, double.infinity);
          // Start label sits to the LEFT of its handle and End label to the
          // RIGHT of its handle, so the two labels do not collide.
          final startLeft =
              (_xOf(s, width) - _labelWidth).clamp(0.0, maxLeft).toDouble();
          final endLeft = _xOf(e, width).clamp(0.0, maxLeft).toDouble();

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (d) => _onDragStart(d, width),
            onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
            onHorizontalDragEnd: (_) => _onDragEnd(),
            onHorizontalDragCancel: _onDragEnd,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: _labelHeight,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Positioned(
                        left: startLeft,
                        width: _labelWidth,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            formatLoopTime(s),
                            key: const Key('waveform_start_label'),
                            style: labelStyle.copyWith(color: _startColor),
                          ),
                        ),
                      ),
                      Positioned(
                        left: endLeft,
                        width: _labelWidth,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatLoopTime(e),
                            key: const Key('waveform_end_label'),
                            style: labelStyle.copyWith(color: _endColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                wave,
              ],
            ),
          );
        },
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
    required this.showHandles,
    required this.startActive,
    required this.endActive,
    required this.barColor,
    required this.regionColor,
    required this.playheadColor,
    required this.startHandleColor,
    required this.endHandleColor,
  });

  final WaveformPeaks peaks;
  final int totalMs;
  final int? startMs;
  final int? endMs;
  final int? positionMs;
  final bool showHandles;
  final bool startActive;
  final bool endActive;
  final Color barColor;
  final Color regionColor;
  final Color playheadColor;
  final Color startHandleColor;
  final Color endHandleColor;

  static const double _barSlot = 3; // 2 px bar + 1 px gap
  static const double _flagWidth = 10;
  static const double _flagHeight = 18;

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

    if (showHandles && s != null && e != null) {
      // Start flag points right (into the region), End flag points left.
      _drawHandle(canvas, size, s, startHandleColor, startActive, pointRight: true);
      _drawHandle(canvas, size, e, endHandleColor, endActive, pointRight: false);
    }
  }

  void _drawHandle(
    Canvas canvas,
    Size size,
    int ms,
    Color color,
    bool active, {
    required bool pointRight,
  }) {
    final x = (ms / totalMs).clamp(0.0, 1.0) * size.width;
    final paint = Paint()..color = color;

    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      paint..strokeWidth = active ? 4 : 3,
    );

    final flagHeight = active ? _flagHeight + 4 : _flagHeight;
    final flag = pointRight
        ? Rect.fromLTWH(x, 0, _flagWidth, flagHeight)
        : Rect.fromLTWH(x - _flagWidth, 0, _flagWidth, flagHeight);
    canvas.drawRect(flag, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.peaks != peaks ||
      old.totalMs != totalMs ||
      old.startMs != startMs ||
      old.endMs != endMs ||
      old.positionMs != positionMs ||
      old.showHandles != showHandles ||
      old.startActive != startActive ||
      old.endActive != endActive ||
      old.barColor != barColor ||
      old.regionColor != regionColor ||
      old.playheadColor != playheadColor ||
      old.startHandleColor != startHandleColor ||
      old.endHandleColor != endHandleColor;
}
