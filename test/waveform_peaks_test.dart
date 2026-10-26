import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/domain/waveform/waveform_peaks.dart';
import 'package:loop_player/presentation/now_playing/waveform_view.dart';

void main() {
  group('WaveformPeaks', () {
    test('durationMs follows peaksPerSecond', () {
      final p = WaveformPeaks(values: List.filled(300, 0.5), peaksPerSecond: 100);
      expect(p.durationMs, 3000);
    });

    test('bars keep the LOUDEST value of each slice', () {
      final p = WaveformPeaks(
          values: const [0.1, 0.5, 0.2, 0.4], peaksPerSecond: 1);
      // Loudest overall is 0.5 -> scaled to 1.0. Slices: [0.1,0.5] [0.2,0.4]
      final b = p.bars(2);
      expect(b.length, 2);
      expect(b[0], closeTo(1.0, 1e-9));
      expect(b[1], closeTo(0.8, 1e-9));
    });

    test('a very quiet song is not blown up to full height', () {
      final p = WaveformPeaks(values: const [0.05, 0.02], peaksPerSecond: 1);
      final b = p.bars(2);
      expect(b[0], closeTo(0.5, 1e-9)); // 0.05 / 0.1 floor
      expect(b[1], closeTo(0.2, 1e-9));
    });

    test('more bars than values still gives exactly that many bars', () {
      final p = WaveformPeaks(values: const [0.2, 0.4], peaksPerSecond: 1);
      final b = p.bars(10);
      expect(b.length, 10);
      expect(b.every((v) => v >= 0 && v <= 1), isTrue);
    });

    test('empty waveform gives silent bars, and zero bars gives none', () {
      final p = WaveformPeaks(values: const [], peaksPerSecond: 100);
      expect(p.bars(4), [0.0, 0.0, 0.0, 0.0]);
      expect(p.bars(0), isEmpty);
      expect(p.durationMs, 0);
    });
  });

  testWidgets('WaveformView draws with and without a region', (tester) async {
    final peaks = WaveformPeaks(
        values: List<double>.generate(1000, (i) => (i % 40) / 40),
        peaksPerSecond: 100);

    Future<void> show({int? s, int? e, int? pos}) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WaveformView(
                peaks: peaks,
                totalMs: 10000,
                startMs: s,
                endMs: e,
                positionMs: pos,
              ),
            ),
          ),
        );

    await show();
    expect(find.byType(WaveformView), findsOneWidget);
    await show(s: 2000, e: 5000, pos: 3000);
    expect(tester.takeException(), isNull);
    // Nonsense input must not crash the painter.
    await show(s: 6000, e: 1000, pos: 99999);
    expect(tester.takeException(), isNull);
  });
}
