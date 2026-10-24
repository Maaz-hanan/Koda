import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/core/loop_time.dart';

void main() {
  group('parseLoopTime', () {
    test('plain seconds', () {
      expect(parseLoopTime('65'), 65000);
      expect(parseLoopTime('0'), 0);
      expect(parseLoopTime(' 12 '), 12000);
    });

    test('minutes and seconds', () {
      expect(parseLoopTime('1:05'), 65000);
      expect(parseLoopTime('0:10'), 10000);
      expect(parseLoopTime('12:00'), 720000);
    });

    test('decimals', () {
      expect(parseLoopTime('65.5'), 65500);
      expect(parseLoopTime('1:05.5'), 65500);
      expect(parseLoopTime('0:00.25'), 250);
      expect(parseLoopTime('0:00.125'), 125);
    });

    test('rejects nonsense', () {
      expect(parseLoopTime(''), isNull);
      expect(parseLoopTime('abc'), isNull);
      expect(parseLoopTime('-5'), isNull);
      expect(parseLoopTime('1:75'), isNull);
      expect(parseLoopTime('1:05.1234'), isNull);
      expect(parseLoopTime('1:'), isNull);
      expect(parseLoopTime('1::05'), isNull);
    });
  });

  group('formatLoopTime', () {
    test('whole seconds have no decimals', () {
      expect(formatLoopTime(0), '0:00');
      expect(formatLoopTime(65000), '1:05');
      expect(formatLoopTime(10000), '0:10');
    });

    test('fractions drop trailing zeros', () {
      expect(formatLoopTime(65500), '1:05.5');
      expect(formatLoopTime(65250), '1:05.25');
      expect(formatLoopTime(125), '0:00.125');
    });

    test('negative becomes 0:00', () {
      expect(formatLoopTime(-1), '0:00');
    });

    test('format then parse gives the same number', () {
      for (final ms in [0, 999, 1000, 65500, 3599999]) {
        expect(parseLoopTime(formatLoopTime(ms)), ms);
      }
    });
  });
}
