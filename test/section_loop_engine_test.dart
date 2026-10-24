import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/domain/loop/section_loop_engine.dart';

void main() {
  group('SectionLoopEngine', () {
    late SectionLoopEngine engine;
    const gen = 1;
    const start = 1000;
    const end = 5000;

    setUp(() {
      engine = SectionLoopEngine();
    });

    test('no session returns none', () {
      expect(engine.onPosition(2000, gen), SectionLoopAction.none);
      expect(engine.hasActiveSession, isFalse);
    });

    test('infinite section loop: seeks to start each time boundary is reached', () {
      engine.startSession(
        loopStartMs: start,
        loopEndMs: end,
        isFinite: false,
        finiteCount: 0,
        trackGeneration: gen,
      );

      expect(engine.hasActiveSession, isTrue);

      // Within region before boundary (end - 200 = 4800)
      expect(engine.onPosition(2000, gen), SectionLoopAction.none);
      expect(engine.onPosition(4700, gen), SectionLoopAction.none);

      // Boundary reached (>= 4800) -> seekToStart
      expect(engine.onPosition(4800, gen), SectionLoopAction.seekToStart);

      // While seekPending, stale events near end are ignored
      expect(engine.onPosition(4900, gen), SectionLoopAction.none);
      expect(engine.onPosition(4950, gen), SectionLoopAction.none);

      // Position lands back near start -> seekPending cleared
      expect(engine.onPosition(1050, gen), SectionLoopAction.none);

      // Progresses again to end -> seekToStart again
      expect(engine.onPosition(3000, gen), SectionLoopAction.none);
      expect(engine.onPosition(4850, gen), SectionLoopAction.seekToStart);
    });

    test('finite section loop: completes after configured count and seeks to end', () {
      engine.startSession(
        loopStartMs: start,
        loopEndMs: end,
        isFinite: true,
        finiteCount: 2,
        trackGeneration: gen,
      );

      // Iteration 1 boundary reached
      expect(engine.onPosition(4850, gen), SectionLoopAction.seekToStart);
      expect(engine.session?.iterationsCompleted, 1);
      expect(engine.hasActiveSession, isTrue);

      // Stale event dropped
      expect(engine.onPosition(4900, gen), SectionLoopAction.none);

      // Settle near start
      expect(engine.onPosition(1000, gen), SectionLoopAction.none);

      // Iteration 2 boundary reached -> count exhausted (2/2) -> loopCompleted
      expect(engine.onPosition(4850, gen), SectionLoopAction.loopCompleted);
      expect(engine.session?.iterationsCompleted, 2);
      expect(engine.hasActiveSession, isFalse);
      expect(engine.session?.isCompleted, isTrue);

      // Subsequent events do nothing
      expect(engine.onPosition(5000, gen), SectionLoopAction.none);
      expect(engine.onPosition(5500, gen), SectionLoopAction.none);
    });

    test('stale generation ID is ignored', () {
      engine.startSession(
        loopStartMs: start,
        loopEndMs: end,
        isFinite: false,
        finiteCount: 0,
        trackGeneration: gen,
      );

      // Event from previous generation (gen - 1)
      expect(engine.onPosition(4900, gen - 1), SectionLoopAction.none);
      // Event from newer generation (gen + 1)
      expect(engine.onPosition(4900, gen + 1), SectionLoopAction.none);
      // Current generation works
      expect(engine.onPosition(4900, gen), SectionLoopAction.seekToStart);
    });

    test('manual seek within loop region sets seekPending without cancelling session', () {
      engine.startSession(
        loopStartMs: start,
        loopEndMs: end,
        isFinite: true,
        finiteCount: 3,
        trackGeneration: gen,
      );

      engine.onManualSeek(3000);
      expect(engine.hasActiveSession, isTrue);
      expect(engine.session?.seekPending, isTrue);

      // Stale event near end ignored
      expect(engine.onPosition(4900, gen), SectionLoopAction.none);

      // Lands at 3000 -> clears seekPending
      expect(engine.onPosition(3000, gen), SectionLoopAction.none);
      expect(engine.session?.seekPending, isFalse);
    });

    test('manual seek outside loop region cancels active session', () {
      engine.startSession(
        loopStartMs: start,
        loopEndMs: end,
        isFinite: false,
        finiteCount: 0,
        trackGeneration: gen,
      );

      // Seek before start
      engine.onManualSeek(500);
      expect(engine.hasActiveSession, isFalse);
      expect(engine.session?.isCompleted, isTrue);

      // Re-arm session
      engine.startSession(
        loopStartMs: start,
        loopEndMs: end,
        isFinite: false,
        finiteCount: 0,
        trackGeneration: gen,
      );

      // Seek after end
      engine.onManualSeek(5500);
      expect(engine.hasActiveSession, isFalse);
      expect(engine.session?.isCompleted, isTrue);
    });

    test('cancelSession stops processing immediately', () {
      engine.startSession(
        loopStartMs: start,
        loopEndMs: end,
        isFinite: false,
        finiteCount: 0,
        trackGeneration: gen,
      );

      engine.cancelSession();
      expect(engine.hasActiveSession, isFalse);
      expect(engine.onPosition(4900, gen), SectionLoopAction.none);
    });

    test('onSongCompleted acts as boundary crossing if position was not caught', () {
      engine.startSession(
        loopStartMs: start,
        loopEndMs: end,
        isFinite: true,
        finiteCount: 1,
        trackGeneration: gen,
      );

      expect(engine.onSongCompleted(gen), SectionLoopAction.loopCompleted);
      expect(engine.session?.iterationsCompleted, 1);
      expect(engine.hasActiveSession, isFalse);
    });
  });
}
