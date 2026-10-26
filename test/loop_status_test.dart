import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/domain/loop/loop_status.dart';
import 'package:loop_player/domain/loop/section_loop_engine.dart';

/// Drives the REAL engine and checks the picture the screen would show.
void main() {
  const gen = 1;

  SectionLoopEngine engineWith({required bool isFinite, int count = 3}) {
    final engine = SectionLoopEngine();
    engine.startSession(
      loopStartMs: 10000,
      loopEndMs: 20000,
      isFinite: isFinite,
      finiteCount: count,
      trackGeneration: gen,
    );
    return engine;
  }

  SectionLoopStatus? statusOf(SectionLoopEngine e) =>
      SectionLoopStatus.fromSession(e.session);

  test('no session means no status', () {
    expect(SectionLoopStatus.fromSession(null), isNull);
  });

  test('a new loop is WAITING and shows all its plays', () {
    final s = statusOf(engineWith(isFinite: true, count: 3))!;
    expect(s.phase, SectionLoopPhase.waiting);
    expect(s.startMs, 10000);
    expect(s.endMs, 20000);
    expect(s.isFinite, isTrue);
    expect(s.playsLeft, 3);
  });

  test('stays waiting while playback is before Start', () {
    final e = engineWith(isFinite: true);
    e.onPosition(5000, gen);
    expect(statusOf(e)!.phase, SectionLoopPhase.waiting);
  });

  test('becomes RUNNING when playback reaches Start', () {
    final e = engineWith(isFinite: true, count: 3);
    e.onPosition(10000, gen);
    final s = statusOf(e)!;
    expect(s.phase, SectionLoopPhase.running);
    expect(s.playsLeft, 3); // the first play is still in progress
  });

  test('plays left counts down and the status disappears at the end', () {
    final e = engineWith(isFinite: true, count: 3);
    e.onPosition(10000, gen); // enters
    e.onPosition(19900, gen); // 1st play done -> seek back
    expect(statusOf(e)!.playsLeft, 2);
    e.onPosition(10000, gen); // seek landed
    e.onPosition(19900, gen); // 2nd play done
    expect(statusOf(e)!.playsLeft, 1);
    e.onPosition(10000, gen);
    e.onPosition(19900, gen); // 3rd play done -> loop finished
    expect(statusOf(e), isNull);
  });

  test('an infinite loop has no plays-left number', () {
    final e = engineWith(isFinite: false);
    e.onPosition(10000, gen);
    for (var i = 0; i < 25; i++) {
      e.onPosition(19900, gen);
      e.onPosition(10000, gen);
    }
    final s = statusOf(e)!;
    expect(s.isFinite, isFalse);
    expect(s.playsLeft, isNull);
    expect(s.phase, SectionLoopPhase.running);
  });

  test('a manual seek before Start puts a running loop back to waiting', () {
    final e = engineWith(isFinite: true, count: 3);
    e.onPosition(10000, gen);
    e.onPosition(19900, gen);
    e.onPosition(10000, gen);
    expect(statusOf(e)!.playsLeft, 2);

    e.onManualSeek(2000);
    final s = statusOf(e)!;
    expect(s.phase, SectionLoopPhase.waiting);
    expect(s.playsLeft, 3); // the count restarts
  });

  test('a cancelled loop has no status', () {
    final e = engineWith(isFinite: false);
    e.cancelSession();
    expect(statusOf(e), isNull);
  });

  test('equal pictures are equal (so the screen only redraws on change)', () {
    final a = statusOf(engineWith(isFinite: true))!;
    final b = statusOf(engineWith(isFinite: true))!;
    expect(a, b);
    expect(a.hashCode, b.hashCode);

    final e = engineWith(isFinite: true);
    e.onPosition(10000, gen);
    expect(statusOf(e), isNot(a));
  });
}
