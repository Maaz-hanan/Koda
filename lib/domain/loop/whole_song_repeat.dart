import 'loop_mode.dart';

/// What the player should do when a song reaches its end.
enum CompletionAction {
  /// Seek back to 0:00 and play the same song again.
  replay,

  /// Move on to the next song in the queue (or finish the queue).
  advance,
}

/// The decision-making for whole-song repeat (Off / Once / Infinite).
/// [PRD §3.1, §13]
///
/// Pure Dart: no audio in here, so every rule can be unit-tested.
/// The audio handler asks this class "what now?" and then does the audio work.
class WholeSongRepeat {
  LoopMode _mode = LoopMode.off;

  /// True while the ONE extra play of "Repeat once" is running.
  bool _replayInProgress = false;

  LoopMode get mode => _mode;

  /// Sets the mode directly. Always clears any half-done "repeat once".
  void setMode(LoopMode mode) {
    _mode = mode;
    _replayInProgress = false;
  }

  /// A short tap on the Loop button. Returns the new mode.
  LoopMode cycle() {
    setMode(nextRepeatMode(_mode));
    return _mode;
  }

  /// The song reached its end naturally.
  CompletionAction onSongCompleted() {
    switch (_mode) {
      case LoopMode.repeatInfinite:
        return CompletionAction.replay;
      case LoopMode.repeatOnce:
        if (!_replayInProgress) {
          _replayInProgress = true; // first finish: do the one extra play
          return CompletionAction.replay;
        }
        // The extra play just finished: back to Off and move on.
        setMode(LoopMode.off);
        return CompletionAction.advance;
      case LoopMode.off:
      case LoopMode.finiteSection:
      case LoopMode.infiniteSection:
        // Section loops are Phase 3; they don't use whole-song repeat.
        return CompletionAction.advance;
    }
  }

  /// A different song is about to play (Next, Previous, a song tapped in the
  /// library, ...). Whole-song repeat ends. [PLAN §4.2: "exit R1 / exit RI"]
  void onTrackChange() => setMode(LoopMode.off);
}
