/// The five possible repeat / loop states recognised by the player.
///
/// Only one mode may be active at a time (PRD §13 priority rule 3).
enum LoopMode {
  /// No repeat — play once and advance the queue.
  off,

  /// Whole-song repeat once — finish the current play, replay the full song
  /// one additional time, then advance the queue (PRD §3.1).
  repeatOnce,

  /// Whole-song repeat infinitely — repeat the full song until the user
  /// changes the mode or presses Next (PRD §3.1).
  repeatInfinite,

  /// Finite section loop — repeat [loopStart, loopEnd] for a configured
  /// number of total plays, then continue from loopEnd (PRD FR-015).
  finiteSection,

  /// Infinite section loop — repeat [loopStart, loopEnd] indefinitely;
  /// only an explicit Next command or mode change exits (PRD FR-016/017).
  infiniteSection,
}

/// What a short tap on the Loop button does. [PRD §3.1]
///
/// Off -> Repeat once -> Repeat infinitely -> Off.
/// A section loop (Phase 3) goes to Off on tap, as in the plan's table.
LoopMode nextRepeatMode(LoopMode current) {
  switch (current) {
    case LoopMode.off:
      return LoopMode.repeatOnce;
    case LoopMode.repeatOnce:
      return LoopMode.repeatInfinite;
    case LoopMode.repeatInfinite:
    case LoopMode.finiteSection:
    case LoopMode.infiniteSection:
      return LoopMode.off;
  }
}
