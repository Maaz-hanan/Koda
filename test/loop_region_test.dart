import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/domain/loop/loop_region.dart';

void main() {
  group('snap', () {
    test('rounds to the nearest 10 ms', () {
      expect(LoopRegion.snap(10004), 10000);
      expect(LoopRegion.snap(10006), 10010);
      expect(LoopRegion.snap(0), 0);
    });
  });

  group('clampStart', () {
    test('a normal move is kept', () {
      expect(LoopRegion.clampStart(5000, endMs: 20000, totalMs: 60000), 5000);
    });

    test('cannot reach End: stays one minimum gap before it', () {
      expect(LoopRegion.clampStart(25000, endMs: 20000, totalMs: 60000), 19900);
      expect(LoopRegion.clampStart(20000, endMs: 20000, totalMs: 60000), 19900);
    });

    test('cannot go below zero', () {
      expect(LoopRegion.clampStart(-500, endMs: 20000, totalMs: 60000), 0);
    });

    test('End very near zero never gives a negative Start', () {
      expect(LoopRegion.clampStart(50, endMs: 50, totalMs: 60000), 0);
    });

    test('works when the song length is unknown (0)', () {
      expect(LoopRegion.clampStart(5000, endMs: 20000, totalMs: 0), 5000);
    });
  });

  group('clampEnd', () {
    test('a normal move is kept', () {
      expect(LoopRegion.clampEnd(30000, startMs: 10000, totalMs: 60000), 30000);
    });

    test('cannot reach Start: stays one minimum gap after it', () {
      expect(LoopRegion.clampEnd(5000, startMs: 10000, totalMs: 60000), 10100);
      expect(LoopRegion.clampEnd(10000, startMs: 10000, totalMs: 60000), 10100);
    });

    test('cannot go past the end of the song', () {
      expect(LoopRegion.clampEnd(70000, startMs: 10000, totalMs: 60000), 60000);
    });

    test('has no upper limit when the song length is unknown (0)', () {
      expect(LoopRegion.clampEnd(70000, startMs: 10000, totalMs: 0), 70000);
    });
  });

  test('moving one handle uses only that handle\'s function', () {
    // Start and End are independent inputs: clamping Start never returns a
    // value that depends on a changed End, and vice versa.
    const start = 10000;
    const end = 20000;
    final newStart = LoopRegion.clampStart(12000, endMs: end, totalMs: 60000);
    final newEnd = LoopRegion.clampEnd(18000, startMs: start, totalMs: 60000);
    expect(newStart, 12000);
    expect(newEnd, 18000);
  });
}
