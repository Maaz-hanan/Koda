import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/models/loop_profile.dart';
import 'package:loop_player/domain/loop/loop_mode.dart';

LoopProfile _profile({
  LoopMode mode = LoopMode.infiniteSection,
  int? start,
  int? end,
  int? count,
}) =>
    LoopProfile(
      songId: 'x',
      mode: mode,
      loopStartMs: start,
      loopEndMs: end,
      finiteCount: count,
      updatedAt: 0,
    );

void main() {
  const duration = 180000;

  test('non-section modes are always valid', () {
    expect(_profile(mode: LoopMode.off).validate(durationMs: duration), isNull);
    expect(_profile(mode: LoopMode.repeatOnce).validate(durationMs: duration),
        isNull);
  });

  test('a good range is accepted', () {
    expect(_profile(start: 10000, end: 20000).validate(durationMs: duration),
        isNull);
  });

  test('start after end is rejected', () {
    expect(_profile(start: 20000, end: 10000).validate(durationMs: duration),
        isNotNull);
  });

  test('start equal to end is rejected', () {
    expect(_profile(start: 5000, end: 5000).validate(durationMs: duration),
        isNotNull);
  });

  test('missing start or end is rejected', () {
    expect(_profile(start: 5000).validate(durationMs: duration), isNotNull);
    expect(_profile().validate(durationMs: duration), isNotNull);
  });

  test('end past the song duration is rejected', () {
    expect(_profile(start: 1000, end: duration + 1).validate(durationMs: duration),
        isNotNull);
  });

  test('negative start is rejected', () {
    expect(_profile(start: -1, end: 5000).validate(durationMs: duration),
        isNotNull);
  });

  test('finite loop needs a count of at least 1', () {
    expect(
        _profile(mode: LoopMode.finiteSection, start: 0, end: 5000)
            .validate(durationMs: duration),
        isNotNull);
    expect(
        _profile(mode: LoopMode.finiteSection, start: 0, end: 5000, count: 0)
            .validate(durationMs: duration),
        isNotNull);
    expect(
        _profile(mode: LoopMode.finiteSection, start: 0, end: 5000, count: 3)
            .validate(durationMs: duration),
        isNull);
  });

  test('survives a save-and-load round trip', () {
    final original = _profile(
        mode: LoopMode.finiteSection, start: 1000, end: 9000, count: 4);
    final copy = LoopProfile.fromMap(original.toMap());
    expect(copy.mode, LoopMode.finiteSection);
    expect(copy.loopStartMs, 1000);
    expect(copy.loopEndMs, 9000);
    expect(copy.finiteCount, 4);
    expect(copy.songId, 'x');
  });

  test('an unknown saved mode falls back to off', () {
    final map = _profile().toMap()..['mode'] = 'somethingFromTheFuture';
    expect(LoopProfile.fromMap(map).mode, LoopMode.off);
  });
}
