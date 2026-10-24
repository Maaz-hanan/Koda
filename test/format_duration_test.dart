import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/core/format_duration.dart';

void main() {
  test('formats zero and negative as 0:00', () {
    expect(formatDurationMs(0), '0:00');
    expect(formatDurationMs(-500), '0:00');
  });

  test('formats seconds and minutes', () {
    expect(formatDurationMs(5000), '0:05');
    expect(formatDurationMs(65000), '1:05');
    expect(formatDurationMs(599000), '9:59');
  });

  test('drops fractions of a second', () {
    expect(formatDurationMs(5999), '0:05');
  });

  test('formats hours', () {
    expect(formatDurationMs(3661000), '1:01:01');
  });
}
