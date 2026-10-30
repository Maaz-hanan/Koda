import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A thin Apple-style bar you can tap or drag: used for the song position
/// and the volume. The track is 6 pt tall and grows to 10 pt while dragging.
///
/// * [onChanged] fires while the finger moves (and on a tap).
/// * [onChangeEnd] fires once when the finger lifts (and on a tap).
/// Values run from 0 to [max]. With [enabled] false nothing reacts.
class ScrubBar extends StatefulWidget {
  const ScrubBar({
    super.key,
    required this.value,
    required this.max,
    this.onChanged,
    this.onChangeEnd,
    this.enabled = true,
    this.semanticLabel,
    this.semanticFormat,
  });

  final double value;
  final double max;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool enabled;
  final String? semanticLabel;

  /// Turns a bar value into spoken words (e.g. "1:05" or "50%"). VoiceOver
  /// needs it for the spoken value and for swipe up / down adjusting.
  final String Function(double value)? semanticFormat;

  @override
  State<ScrubBar> createState() => _ScrubBarState();
}

class _ScrubBarState extends State<ScrubBar> {
  bool _dragging = false;
  double _last = 0;

  /// Current width of the bar. Read from the render box (not a
  /// LayoutBuilder) so the bar also works inside IntrinsicHeight.
  double get _width {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.width : 0;
  }

  double _valueAt(double dx) {
    final width = _width;
    if (width <= 0) return 0;
    return (dx / width).clamp(0.0, 1.0).toDouble() * widget.max;
  }

  void _moveTo(double dx) {
    _last = _valueAt(dx);
    widget.onChanged?.call(_last);
  }

  void _finishDrag() {
    if (!_dragging) return;
    setState(() => _dragging = false);
    widget.onChangeEnd?.call(_last);
  }

  void _step(int direction) {
    final v = (widget.value + direction * widget.max * 0.05)
        .clamp(0.0, widget.max)
        .toDouble();
    widget.onChanged?.call(v);
    widget.onChangeEnd?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final fraction = widget.max <= 0
        ? 0.0
        : (widget.value / widget.max).clamp(0.0, 1.0).toDouble();
    final thickness = _dragging ? 10.0 : 6.0;
    final on = widget.enabled;

    final format = widget.semanticFormat;
    double stepped(int direction) => (widget.value + direction * widget.max * 0.05)
        .clamp(0.0, widget.max)
        .toDouble();

    return Semantics(
      slider: true,
      enabled: on,
      label: widget.semanticLabel,
      // value, increasedValue and decreasedValue must all be set or all unset.
      value: format?.call(widget.value),
      increasedValue: format?.call(stepped(1)),
      decreasedValue: format?.call(stepped(-1)),
      onIncrease: on ? () => _step(1) : null,
      onDecrease: on ? () => _step(-1) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: on
            ? (d) {
                final v = _valueAt(d.localPosition.dx);
                widget.onChanged?.call(v);
                widget.onChangeEnd?.call(v);
              }
            : null,
        onHorizontalDragStart: on
            ? (d) {
                setState(() => _dragging = true);
                _moveTo(d.localPosition.dx);
              }
            : null,
        onHorizontalDragUpdate: on ? (d) => _moveTo(d.localPosition.dx) : null,
        onHorizontalDragEnd: on ? (_) => _finishDrag() : null,
        onHorizontalDragCancel: on ? _finishDrag : null,
        child: SizedBox(
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: thickness,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: ColoredBox(
                    color: AppColors.progressTrack,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        key: const ValueKey('scrub_played'),
                        widthFactor: fraction,
                        heightFactor: 1,
                        child:
                            const ColoredBox(color: AppColors.progressPlayed),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
