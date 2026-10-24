/// Transient runtime state for an active section loop. [PRD FR-020]
///
/// Never written to the database. Created when a song with a section-loop
/// profile starts playing (or the editor saves), and thrown away on track
/// change, cancel, or completion.
class ActiveLoopSession {
  ActiveLoopSession({
    required this.loopStartMs,
    required this.loopEndMs,
    required this.isFinite,
    required this.finiteCount,
    required this.trackGeneration,
  });

  /// Section start in milliseconds.
  final int loopStartMs;

  /// Section end in milliseconds.
  final int loopEndMs;

  /// True for [LoopMode.finiteSection], false for [LoopMode.infiniteSection].
  final bool isFinite;

  /// How many total plays of the section are configured (finite only).
  final int finiteCount;

  /// The [_generation] value from the audio handler when this session was
  /// created. Position events with a different generation are stale.
  final int trackGeneration;

  /// How many complete plays of the section have happened so far.
  int iterationsCompleted = 0;

  /// True after a finite loop exhausts its count, or after [cancelSession].
  bool isCompleted = false;

  /// True while the player is seeking back to [loopStartMs] and we have not
  /// yet received a position event confirming the seek landed. Prevents stale
  /// events near [loopEndMs] from being treated as a new boundary crossing.
  bool seekPending = false;
}
