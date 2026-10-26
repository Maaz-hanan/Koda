import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/domain/playback/preview_session.dart';

PreviewSession _session({int start = 10000, int end = 20000, int gen = 1}) =>
    PreviewSession(regionStartMs: start, endMs: end, trackGeneration: gen);

void main() {
  test('starts 2 s before the region', () {
    expect(_session(start: 10000).playFromMs, 8000);
  });

  test('never starts before 0:00', () {
    expect(_session(start: 1500).playFromMs, 0);
    expect(_session(start: 0).playFromMs, 0);
  });

  test('keeps playing inside the lead-in and the region', () {
    final s = _session();
    expect(s.onPosition(8000, 1), PreviewAction.none);
    expect(s.onPosition(12000, 1), PreviewAction.none);
    expect(s.onPosition(19800, 1), PreviewAction.none);
  });

  test('finishes when the end is reached', () {
    final s = _session();
    s.onPosition(8000, 1); // landed
    expect(s.onPosition(19900, 1), PreviewAction.finished);
  });

  test('finishes if the position jumps past the end', () {
    final s = _session();
    s.onPosition(8100, 1);
    expect(s.onPosition(20300, 1), PreviewAction.finished);
  });

  test('an old position past the End before the seek lands is ignored', () {
    final s = _session();
    // The player was at 0:45 when Preview was pressed.
    expect(s.onPosition(45000, 1), PreviewAction.none);
    expect(s.landed, isFalse);
    // Now the seek lands and playback runs normally.
    expect(s.onPosition(8050, 1), PreviewAction.none);
    expect(s.landed, isTrue);
    expect(s.onPosition(19950, 1), PreviewAction.finished);
  });

  test('updates from another track generation are ignored', () {
    final s = _session(gen: 3);
    expect(s.onPosition(8000, 2), PreviewAction.none);
    expect(s.landed, isFalse);
    expect(s.onPosition(8000, 3), PreviewAction.none);
    expect(s.landed, isTrue);
    expect(s.onPosition(25000, 2), PreviewAction.none); // stale, ignored
  });
}
