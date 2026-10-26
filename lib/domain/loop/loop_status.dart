import 'dart:math' as math;

import 'active_loop_session.dart';

/// Where a section loop is right now.
enum SectionLoopPhase {
  /// The loop is set ("armed") but playback has not reached its Start yet,
  /// so the song is playing normally.
  waiting,

  /// Playback is inside the loop and it is repeating.
  running,
}

/// A read-only picture of the current section loop, for the screen.
/// [PRD FR-025, FR-042]
///
/// Pure Dart, no audio and no Flutter. The audio handler builds one of these
/// from the engine's [ActiveLoopSession] whenever something changes, and the
/// Now Playing screen only displays it. It is a copy: changing it never
/// changes the engine.
class SectionLoopStatus {
  const SectionLoopStatus({
    required this.startMs,
    required this.endMs,
    required this.isFinite,
    required this.phase,
    this.playsLeft,
  });

  final int startMs;
  final int endMs;

  /// True for a finite loop, false for an infinite one.
  final bool isFinite;

  final SectionLoopPhase phase;

  /// Plays still to go for a finite loop, INCLUDING the one in progress
  /// ("3 left" on the first play of a 3-play loop). Null for infinite loops.
  final int? playsLeft;

  /// Builds the status from the engine's session. Returns null when there is
  /// no loop to show (no session, cancelled, or finished).
  static SectionLoopStatus? fromSession(ActiveLoopSession? session) {
    if (session == null || session.isCompleted) return null;
    return SectionLoopStatus(
      startMs: session.loopStartMs,
      endMs: session.loopEndMs,
      isFinite: session.isFinite,
      phase:
          session.entered ? SectionLoopPhase.running : SectionLoopPhase.waiting,
      playsLeft: session.isFinite
          ? math.max(0, session.finiteCount - session.iterationsCompleted)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SectionLoopStatus &&
          other.startMs == startMs &&
          other.endMs == endMs &&
          other.isFinite == isFinite &&
          other.phase == phase &&
          other.playsLeft == playsLeft);

  @override
  int get hashCode => Object.hash(startMs, endMs, isFinite, phase, playsLeft);
}
