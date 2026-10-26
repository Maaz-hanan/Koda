/// Rules for moving the Start / End handles of a loop region.
/// [PRD FR-028, FR-030, FR-032]
///
/// Pure Dart (no Flutter), so it can be unit-tested. The editor and the
/// waveform use these functions so dragging and the +/-100 ms buttons always
/// follow the same rules:
///  * Start can never reach or pass End (and the other way round).
///  * Neither handle can leave 0 .. song length.
///  * Moving one handle never moves the other one.
class LoopRegion {
  LoopRegion._();

  /// Smallest allowed distance between Start and End.
  static const int minGapMs = 100;

  /// Size of one tap on the +/- buttons.
  static const int nudgeMs = 100;

  /// Dragging snaps to this step (the waveform has one value per 10 ms).
  static const int dragStepMs = 10;

  /// Rounds [ms] to the nearest [dragStepMs].
  static int snap(int ms) => (ms / dragStepMs).round() * dragStepMs;

  /// Where Start may go. [totalMs] <= 0 means "song length unknown".
  static int clampStart(
    int proposedMs, {
    required int endMs,
    required int totalMs,
  }) {
    var upper = endMs - minGapMs;
    if (totalMs > 0 && upper > totalMs - minGapMs) upper = totalMs - minGapMs;
    if (upper < 0) upper = 0;
    if (proposedMs < 0) return 0;
    if (proposedMs > upper) return upper;
    return proposedMs;
  }

  /// Where End may go. [totalMs] <= 0 means "song length unknown".
  static int clampEnd(
    int proposedMs, {
    required int startMs,
    required int totalMs,
  }) {
    final lower = startMs + minGapMs;
    var result = proposedMs < lower ? lower : proposedMs;
    // If Start is so close to the end of the song that the minimum gap does
    // not fit, End stays at the song end; saving then reports the problem.
    if (totalMs > 0 && result > totalMs) result = totalMs;
    return result;
  }
}
