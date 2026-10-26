import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/domain/loop/section_loop_engine.dart';

void main() {
  group('SectionLoopEngine', () {
    late SectionLoopEngine engine;
    const gen = 1;
    const start = 1000;
    const end = 5000;

    void startLoop({required bool isFinite, int count = 0}) =>
        engine.startSession(
          loopStartMs: start,
          loopEndMs: end,
          isFinite: isFinite,
          finiteCount: count,
          trackGeneration: gen,
        );

    setUp(() {
      engine = SectionLoopEngine();
    });

    test('no session returns none', () {
      expect(engine.onPosition(2000, gen), SectionLoopAction.none);
      expect(engine.hasActiveSession, isFalse);
    });

    group('armed (waiting for the loop start)', () {
      test('a new session is armed and does nothing before the start', () {
        startLoop(isFinite: false);
        expect(engine.hasActiveSession, isTrue);
        expect(engine.session?.entered, isFalse);

        expect(engine.onPosition(0, gen), SectionLoopAction.none);
        expect(engine.onPosition(500, gen), SectionLoopAction.none);
        expect(engine.onPosition(999, gen), SectionLoopAction.none);
        expect(engine.session?.entered, isFalse);
        expect(engine.session?.iterationsCompleted, 0);
      });

      test('enters when playback reaches the start, then loops', () {
        startLoop(isFinite: false);
        expect(engine.onPosition(900, gen), SectionLoopAction.none);
        expect(engine.onPosition(1100, gen), SectionLoopAction.none);
        expect(engine.session?.entered, isTrue);
        expect(engine.onPosition(4850, gen), SectionLoopAction.seekToStart);
      });

      test('loop set while the playhead is already past the end never loops',
          () {
        startLoop(isFinite: true, count: 2);
        expect(engine.onPosition(5200, gen), SectionLoopAction.none);
        expect(engine.onPosition(8000, gen), SectionLoopAction.none);
        expect(engine.session?.entered, isFalse);
        expect(engine.session?.iterationsCompleted, 0);
        expect(engine.hasActiveSession, isTrue);
      });

      test('loop set while the playhead is inside the region starts at once',
          () {
        startLoop(isFinite: false);
        expect(engine.onPosition(3000, gen), SectionLoopAction.none);
        expect(engine.session?.entered, isTrue);
        expect(engine.onPosition(4850, gen), SectionLoopAction.seekToStart);
      });

      test('song ending while still armed means no loop', () {
        startLoop(isFinite: false);
        expect(engine.onSongCompleted(gen), SectionLoopAction.none);
      });
    });

    test('infinite section loop: seeks to start each time boundary is reached',
        () {
      startLoop(isFinite: false);
      expect(engine.hasActiveSession, isTrue);

      expect(engine.onPosition(2000, gen), SectionLoopAction.none);
      expect(engine.onPosition(4700, gen), SectionLoopAction.none);

      // Boundary reached (>= 4800) -> seekToStart
      expect(engine.onPosition(4800, gen), SectionLoopAction.seekToStart);

      // While seekPending, stale events near end are ignored
      expect(engine.onPosition(4900, gen), SectionLoopAction.none);
      expect(engine.onPosition(4950, gen), SectionLoopAction.none);

      // Position lands back near start -> seekPending cleared
      expect(engine.onPosition(1050, gen), SectionLoopAction.none);

      expect(engine.onPosition(3000, gen), SectionLoopAction.none);
      expect(engine.onPosition(4850, gen), SectionLoopAction.seekToStart);
    });

    test('infinite loop keeps going well past 20 repetitions', () {
      startLoop(isFinite: false);
      for (var i = 0; i < 25; i++) {
        expect(engine.onPosition(4850, gen), SectionLoopAction.seekToStart);
        expect(engine.onPosition(1100, gen), SectionLoopAction.none);
      }
      expect(engine.hasActiveSession, isTrue);
    });

    test('finite section loop: exactly N plays, then seeks to end', () {
      startLoop(isFinite: true, count: 2);

      // Play 1 reaches the end
      expect(engine.onPosition(4850, gen), SectionLoopAction.seekToStart);
      expect(engine.session?.iterationsCompleted, 1);
      expect(engine.hasActiveSession, isTrue);

      // Stale event dropped, then settle near start
      expect(engine.onPosition(4900, gen), SectionLoopAction.none);
      expect(engine.onPosition(1000, gen), SectionLoopAction.none);

      // Play 2 reaches the end -> count exhausted (2/2)
      expect(engine.onPosition(4850, gen), SectionLoopAction.loopCompleted);
      expect(engine.session?.iterationsCompleted, 2);
      expect(engine.hasActiveSession, isFalse);

      // Nothing more happens
      expect(engine.onPosition(5000, gen), SectionLoopAction.none);
      expect(engine.onPosition(5500, gen), SectionLoopAction.none);
    });

    test('stale generation ID is ignored', () {
      startLoop(isFinite: false);
      expect(engine.onPosition(4900, gen - 1), SectionLoopAction.none);
      expect(engine.onPosition(4900, gen + 1), SectionLoopAction.none);
      expect(engine.onPosition(4900, gen), SectionLoopAction.seekToStart);
    });

    group('manual seeking', () {
      test('inside the region keeps the loop and guards stale events', () {
        startLoop(isFinite: true, count: 3);
        engine.onManualSeek(3000);
        expect(engine.hasActiveSession, isTrue);
        expect(engine.session?.seekPending, isTrue);

        expect(engine.onPosition(4900, gen), SectionLoopAction.none); // stale
        expect(engine.onPosition(3000, gen), SectionLoopAction.none);
        expect(engine.session?.seekPending, isFalse);
        expect(engine.session?.iterationsCompleted, 0); // no extra count
      });

      test('into the last few ms of the region does not get stuck', () {
        startLoop(isFinite: false);
        engine.onManualSeek(4900); // inside the 200 ms boundary window
        expect(engine.session?.seekPending, isFalse);
        expect(engine.onPosition(4900, gen), SectionLoopAction.seekToStart);
      });

      test('before the start re-arms a running loop', () {
        startLoop(isFinite: true, count: 3);
        expect(engine.onPosition(4850, gen), SectionLoopAction.seekToStart);
        expect(engine.onPosition(1100, gen), SectionLoopAction.none);
        expect(engine.session?.iterationsCompleted, 1);

        engine.onManualSeek(200);
        expect(engine.hasActiveSession, isTrue);
        expect(engine.session?.entered, isFalse);
        expect(engine.session?.iterationsCompleted, 0);

        // Plays normally up to the start, then the loop begins again.
        expect(engine.onPosition(600, gen), SectionLoopAction.none);
        expect(engine.onPosition(1200, gen), SectionLoopAction.none);
        expect(engine.session?.entered, isTrue);
        expect(engine.onPosition(4850, gen), SectionLoopAction.seekToStart);
      });

      test('past the end ends a running loop', () {
        startLoop(isFinite: false);
        expect(engine.onPosition(2000, gen), SectionLoopAction.none);
        engine.onManualSeek(5500);
        expect(engine.hasActiveSession, isFalse);
        expect(engine.onPosition(5600, gen), SectionLoopAction.none);
      });

      test('past the end keeps a not-yet-started loop armed', () {
        startLoop(isFinite: false);
        engine.onManualSeek(5500);
        expect(engine.hasActiveSession, isTrue);
        expect(engine.onPosition(5600, gen), SectionLoopAction.none);
        // Seek back before the start: it will begin when reached.
        engine.onManualSeek(0);
        expect(engine.onPosition(1100, gen), SectionLoopAction.none);
        expect(engine.session?.entered, isTrue);
      });
    });

    test('cancelSession stops processing immediately', () {
      startLoop(isFinite: false);
      engine.cancelSession();
      expect(engine.hasActiveSession, isFalse);
      expect(engine.onPosition(4900, gen), SectionLoopAction.none);
    });

    test('onSongCompleted acts as boundary crossing once the loop has started',
        () {
      startLoop(isFinite: true, count: 1);
      expect(engine.onPosition(2000, gen), SectionLoopAction.none); // enters
      expect(engine.onSongCompleted(gen), SectionLoopAction.loopCompleted);
      expect(engine.session?.iterationsCompleted, 1);
      expect(engine.hasActiveSession, isFalse);
    });
  });
}
