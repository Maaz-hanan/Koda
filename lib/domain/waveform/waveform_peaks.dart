import 'dart:math' as math;

/// A simple, package-independent picture of a song's loudness over time.
/// [PRD FR-026]
///
/// [values] are evenly spaced in time, each between 0.0 (silence) and 1.0
/// (full scale). The drawing code only knows about this class, so the
/// waveform package can be swapped without touching any screen.
class WaveformPeaks {
  WaveformPeaks({required this.values, required this.peaksPerSecond});

  /// Loudness per slice of time, 0.0 .. 1.0.
  final List<double> values;

  /// How many [values] make up one second of audio (e.g. 100).
  final double peaksPerSecond;

  int _cachedCount = -1;
  List<double> _cachedBars = const [];

  /// Length of the audio this waveform covers, in milliseconds.
  int get durationMs =>
      peaksPerSecond <= 0 ? 0 : (values.length / peaksPerSecond * 1000).round();

  /// The loudest value in [values].
  double get maxValue {
    var m = 0.0;
    for (final v in values) {
      if (v > m) m = v;
    }
    return m;
  }

  /// Squeezes the waveform into exactly [count] bars for drawing.
  ///
  /// Each bar shows the LOUDEST value in its slice of time (so short loud
  /// hits are not lost). Bars are scaled so the loudest one is full height,
  /// but very quiet songs are not blown up into noise (floor of 0.1).
  /// The result is cached for the last [count].
  List<double> bars(int count) {
    if (count <= 0) return const [];
    if (count == _cachedCount) return _cachedBars;

    final n = values.length;
    final out = List<double>.filled(count, 0.0);
    if (n > 0) {
      final scale = 1.0 / math.max(maxValue, 0.1);
      for (var b = 0; b < count; b++) {
        final from = math.min((b * n / count).floor(), n - 1);
        final to = math.min(math.max(from + 1, ((b + 1) * n / count).ceil()), n);
        var peak = 0.0;
        for (var i = from; i < to; i++) {
          if (values[i] > peak) peak = values[i];
        }
        out[b] = math.min(peak * scale, 1.0);
      }
    }
    _cachedCount = count;
    _cachedBars = out;
    return out;
  }
}
