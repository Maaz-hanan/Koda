import 'waveform_peaks.dart';

/// Anything that can produce a [WaveformPeaks] for a song.
/// The real one reads the audio file; tests use a fake.
abstract class WaveformLoader {
  /// Returns the waveform for [songId]. [onProgress] gets 0.0 .. 1.0 while
  /// it is being generated (not called when it comes from the cache).
  /// Throws [WaveformException] with a message safe to show the user.
  Future<WaveformPeaks> load(
    String songId, {
    void Function(double progress)? onProgress,
  });
}

class WaveformException implements Exception {
  WaveformException(this.message);
  final String message;

  @override
  String toString() => message;
}
