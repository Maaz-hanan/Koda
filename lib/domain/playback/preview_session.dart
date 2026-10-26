/// What the audio handler should do after a position update during Preview.
enum PreviewAction {
  /// Keep playing.
  none,

  /// The end of the region was reached: stop the preview.
  finished,
}

/// One run of the loop editor's Preview button. [PRD FR-029]
///
/// Pure Dart (no audio, no Flutter), so it can be unit-tested. The audio
/// handler creates one when Preview starts, feeds it position updates, and
/// pauses when it says [PreviewAction.finished]. While a preview exists the
/// section-loop engine is NOT fed any positions, so the saved loop cannot
/// fight the preview. [PRD §13 rule 3]
class PreviewSession {
  PreviewSession({
    required this.regionStartMs,
    required this.endMs,
    required this.trackGeneration,
  });

  /// Stop this early: position updates only arrive every ~200 ms, so waiting
  /// for the exact end would run past it more often than not.
  static const int endToleranceMs = 100;

  /// A position this close to [playFromMs] means the preview seek has landed.
  static const int landingWindowMs = 1000;

  final int regionStartMs;
  final int endMs;

  /// The handler's track generation when the preview began; updates from any
  /// other generation are stale and ignored.
  final int trackGeneration;

  /// False until the seek to [playFromMs] has shown up in the position
  /// updates. Until then old positions (e.g. past the End) are ignored so
  /// they cannot end the preview immediately.
  bool landed = false;

  /// Where playback starts: exactly at the region's Start.
  int get playFromMs => regionStartMs;

  PreviewAction onPosition(int positionMs, int generation) {
    if (generation != trackGeneration) return PreviewAction.none;
    if (!landed) {
      if ((positionMs - playFromMs).abs() <= landingWindowMs) {
        landed = true;
      } else {
        return PreviewAction.none;
      }
    }
    return positionMs >= endMs - endToleranceMs
        ? PreviewAction.finished
        : PreviewAction.none;
  }
}
