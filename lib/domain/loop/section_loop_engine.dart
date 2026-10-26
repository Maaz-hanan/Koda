import 'dart:math' as math;

import 'active_loop_session.dart';

/// What the audio handler should do after processing a position event.
enum SectionLoopAction {
  /// No action needed — position is inside the loop region, or no session.
  none,

  /// Seek the player to [ActiveLoopSession.loopStartMs].
  seekToStart,

  /// The finite loop count is exhausted. Seek to [ActiveLoopSession.loopEndMs]
  /// and continue normal playback (the session is now completed).
  loopCompleted,
}

/// Pure-Dart section-loop engine. No audio, no Flutter — fully unit-testable.
///
/// The audio handler feeds position events into [onPosition] and acts on the
/// returned [SectionLoopAction]. The engine never touches the player itself.
/// [PRD FR-014..FR-025, §13]
class SectionLoopEngine {
  /// How close (in ms) to [loopEndMs] counts as "reached the boundary".
  ///
  /// `just_audio`'s positionStream on iOS fires roughly every 200 ms, so we
  /// need a window at least that wide to avoid missing the boundary.
  static const int toleranceMs = 200;

  ActiveLoopSession? _session;

  /// The current session, or null.
  ActiveLoopSession? get session => _session;

  /// True when a section loop is active and has not yet completed or been
  /// cancelled.
  bool get hasActiveSession => _session != null && !_session!.isCompleted;

  /// Begin a new section-loop session. Any previous session is replaced.
  ///
  /// The session starts ARMED: nothing happens (no seeking, no counting)
  /// until playback reaches [loopStartMs] by itself.
  void startSession({
    required int loopStartMs,
    required int loopEndMs,
    required bool isFinite,
    required int finiteCount,
    required int trackGeneration,
  }) {
    _session = ActiveLoopSession(
      loopStartMs: loopStartMs,
      loopEndMs: loopEndMs,
      isFinite: isFinite,
      finiteCount: finiteCount,
      trackGeneration: trackGeneration,
    );
  }

  /// Mark the current session as completed. All future position events are
  /// ignored until a new session starts.
  void cancelSession() {
    final s = _session;
    if (s != null) s.isCompleted = true;
  }

  /// Called on every position update from the audio player.
  ///
  /// [positionMs] is the current playback position in milliseconds.
  /// [trackGeneration] is the handler's current generation counter — if it
  /// does not match the session's, the event is stale and is ignored.
  SectionLoopAction onPosition(int positionMs, int trackGeneration) {
    final s = _session;
    if (s == null || s.isCompleted) return SectionLoopAction.none;
    if (trackGeneration != s.trackGeneration) return SectionLoopAction.none;

    final length = s.loopEndMs - s.loopStartMs;
    final effectiveTolerance =
        length > 0 ? math.min(toleranceMs, length ~/ 2) : toleranceMs;

    // While a seek-to-start is in flight, ignore all position events until
    // the position settles clearly inside the loop region (away from the end
    // boundary). This prevents stale events near loopEnd from triggering
    // another seek.
    if (s.seekPending) {
      if (positionMs < s.loopEndMs - effectiveTolerance) {
        s.seekPending = false;
      }
      return SectionLoopAction.none;
    }

    // Armed: wait until playback reaches the loop region by itself. Before the
    // start, or already past the end, the song just plays normally.
    if (!s.entered) {
      if (positionMs < s.loopStartMs || positionMs >= s.loopEndMs) {
        return SectionLoopAction.none;
      }
      s.entered = true;
    }

    // Reached (or about to reach) the loop-end boundary.
    if (positionMs >= s.loopEndMs - effectiveTolerance) {
      if (s.isFinite) {
        s.iterationsCompleted++;
        if (s.iterationsCompleted >= s.finiteCount) {
          s.isCompleted = true;
          return SectionLoopAction.loopCompleted;
        }
      }
      s.seekPending = true;
      return SectionLoopAction.seekToStart;
    }

    return SectionLoopAction.none;
  }

  /// Called when the user manually seeks (drag on the seek bar, lock screen,
  /// Previous-restart, ...).
  ///
  /// * Before the loop start → the loop is re-armed: playback continues
  ///   normally and the loop starts again when it reaches the start.
  /// * Past the loop end → if the loop was running it ends (playback
  ///   continues normally, [PLAN §4.2]); if it had not started yet it stays
  ///   armed.
  /// * Inside the region → [seekPending] guards against stale position
  ///   events, so no extra repetition is counted.
  void onManualSeek(int targetMs) {
    final s = _session;
    if (s == null || s.isCompleted) return;

    if (targetMs < s.loopStartMs) {
      s.entered = false;
      s.seekPending = false;
      s.iterationsCompleted = 0;
    } else if (targetMs >= s.loopEndMs) {
      s.seekPending = false;
      if (s.entered) s.isCompleted = true;
    } else {
      // A seek into the last few ms of the region would never be "confirmed"
      // by a later position below the boundary, so don't wait for that.
      final length = s.loopEndMs - s.loopStartMs;
      final tolerance =
          length > 0 ? math.min(toleranceMs, length ~/ 2) : toleranceMs;
      s.seekPending = targetMs < s.loopEndMs - tolerance;
    }
  }

  /// Called when the track's [ProcessingState] reaches `completed` while a
  /// section loop is still active. This is a safety net — the position-based
  /// detection should normally catch the boundary first. Treats the event as
  /// a boundary crossing.
  SectionLoopAction onSongCompleted(int trackGeneration) {
    final s = _session;
    if (s == null || s.isCompleted) return SectionLoopAction.none;
    if (trackGeneration != s.trackGeneration) return SectionLoopAction.none;
    // The song ended without the loop ever starting: nothing to loop.
    if (!s.entered) return SectionLoopAction.none;

    if (s.isFinite) {
      s.iterationsCompleted++;
      if (s.iterationsCompleted >= s.finiteCount) {
        s.isCompleted = true;
        return SectionLoopAction.loopCompleted;
      }
    }
    s.seekPending = true;
    return SectionLoopAction.seekToStart;
  }
}
