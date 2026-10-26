import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/domain/autoloop/auto_loop_analyzer.dart';
import 'package:loop_player/domain/autoloop/auto_loop_config.dart';
import 'package:loop_player/domain/autoloop/auto_loop_result.dart';

/// A fake "song": a short loud burst on every beat (every 4th beat louder).
List<double> clicks(
  double seconds,
  double bpm, {
  double pps = 100,
  double amp = 0.9,
}) {
  final n = (seconds * pps).floor();
  final v = List<double>.filled(n, 0.03);
  final period = 60 / bpm * pps;
  final decay = math.pow(0.85, 100 / pps).toDouble();
  final burst = (25 * pps / 100).floor() + 1;
  for (var k = 0;; k++) {
    final t = (k * period).round();
    if (t >= n) break;
    final a = amp * (k % 4 == 0 ? 1.0 : 0.7);
    for (var j = 0; j < burst; j++) {
      if (t + j < n) {
        final value = a * math.pow(decay, j).toDouble();
        if (value > v[t + j]) v[t + j] = value;
      }
    }
  }
  return v;
}

AutoLoopResult run(
  List<double> values,
  AutoLoopStyle style,
  int targetMs, {
  double pps = 100,
}) =>
    AutoLoopAnalyzer.analyze(
      values: values,
      peaksPerSecond: pps,
      settings: AutoLoopSettings(targetMs: targetMs, style: style),
    );

void main() {
  group('Beat estimate', () {
    for (final bpm in [70.0, 100.0, 140.0]) {
      test('finds about $bpm BPM on a steady beat', () {
        final r = run(clicks(90, bpm), AutoLoopStyle.beat, 16000);
        expect(r.estimatedBpm, isNotNull);
        expect(r.estimatedBpm!, closeTo(bpm, 1.5));
      });
    }

    test('works with a different waveform resolution (50 per second)', () {
      final r = run(clicks(80, 120, pps: 50), AutoLoopStyle.beat, 16000,
          pps: 50);
      expect(r.estimatedBpm, isNotNull);
      expect(r.estimatedBpm!, closeTo(120, 1.5));
    });

    test('random noise has no clear beat', () {
      final rnd = math.Random(1);
      final noise = List<double>.generate(
        6000,
        (_) => (0.3 + (rnd.nextDouble() - 0.5) * 0.3).clamp(0.0, 1.0),
      );
      final r = run(noise, AutoLoopStyle.beat, 10000);
      expect(r.estimatedBpm, isNull);
      // Beat-aligned was asked for: if anything was found, it fell back.
      if (r.found) {
        expect(r.fellBackToEnergy, isTrue);
        expect(r.styleUsed, AutoLoopStyle.energy);
      }
    });
  });

  group('Styles', () {
    test('Beat-aligned: Start and End sit on the beat grid', () {
      final r = run(clicks(60, 120), AutoLoopStyle.beat, 16000);
      expect(r.found, isTrue);
      expect(r.styleUsed, AutoLoopStyle.beat);
      expect(r.fellBackToEnergy, isFalse);
      final best = r.best!;
      // 120 BPM = a beat every 500 ms.
      final offBeat = best.startMs % 500;
      expect(math.min(offBeat, 500 - offBeat), lessThanOrEqualTo(30));
      expect(best.durationMs, closeTo(16000, 30));
    });

    test('Exact: the length is exactly the target', () {
      final r = run(clicks(60, 120), AutoLoopStyle.exact, 16000);
      expect(r.found, isTrue);
      expect(r.styleUsed, AutoLoopStyle.exact);
      expect(r.best!.durationMs, 16000);
    });

    test('Energy: length is near the target', () {
      final r = run(clicks(60, 120), AutoLoopStyle.energy, 16000);
      expect(r.found, isTrue);
      expect(r.styleUsed, AutoLoopStyle.energy);
      expect(r.best!.durationMs, closeTo(16000, 4000));
    });

    test('result stays inside the song, in 10 ms steps, with 0..1 confidence',
        () {
      final song = clicks(75, 128);
      for (final style in AutoLoopStyle.values) {
        final r = run(song, style, 20000);
        expect(r.found, isTrue, reason: style.name);
        for (final c in [r.best!, ...r.alternatives]) {
          expect(c.startMs, greaterThanOrEqualTo(0));
          expect(c.endMs, lessThanOrEqualTo(75000));
          expect(c.startMs, lessThan(c.endMs));
          expect(c.startMs % 10, 0);
          expect(c.endMs % 10, 0);
          expect(c.confidence, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('alternatives start at least 2 s away from the best', () {
      final r = run(clicks(75, 128), AutoLoopStyle.exact, 20000);
      for (final alt in r.alternatives) {
        expect((alt.startMs - r.best!.startMs).abs(), greaterThanOrEqualTo(1990));
      }
      expect(r.alternatives.length,
          lessThanOrEqualTo(AutoLoopTuning.maxAlternatives));
    });
  });

  group('Honest failures', () {
    test('a silent song is reported as silent', () {
      final r = run(List<double>.filled(6000, 0.0), AutoLoopStyle.exact, 10000);
      expect(r.found, isFalse);
      expect(r.failure, AutoLoopFailure.silent);
    });

    test('a song shorter than a few seconds is too short', () {
      final r = run(clicks(4, 120), AutoLoopStyle.exact, 5000);
      expect(r.found, isFalse);
      expect(r.failure, AutoLoopFailure.tooShort);
    });

    test('a target much longer than the song is too short', () {
      final r = run(clicks(10, 120), AutoLoopStyle.exact, 60000);
      expect(r.found, isFalse);
      expect(r.failure, AutoLoopFailure.tooShort);
    });

    test('empty waveform does not crash', () {
      final r = run(const [], AutoLoopStyle.exact, 10000);
      expect(r.found, isFalse);
      expect(r.failure, AutoLoopFailure.tooShort);
    });
  });

  group('Content', () {
    test('a loop is not placed in the silent half of a song', () {
      final song = [...clicks(30, 100), ...List<double>.filled(3000, 0.0)];
      final r = run(song, AutoLoopStyle.exact, 10000);
      expect(r.found, isTrue);
      expect(r.best!.endMs, lessThanOrEqualTo(30100));
    });

    test('a loop does not straddle a big loudness change', () {
      final song = [...clicks(40, 120, amp: 0.9), ...clicks(40, 120, amp: 0.2)];
      final r = run(song, AutoLoopStyle.exact, 20000);
      expect(r.found, isTrue);
      final b = r.best!;
      expect(b.endMs <= 40100 || b.startMs >= 39900, isTrue);
    });
  });

  group('Safety', () {
    test('does not change the waveform it is given', () {
      final song = clicks(30, 120);
      final copy = List<double>.of(song);
      run(song, AutoLoopStyle.beat, 10000);
      expect(song, copy);
    });

    test('runAutoLoopAnalysis gives the same answer as analyze', () {
      final song = clicks(40, 120);
      const settings = AutoLoopSettings(targetMs: 10000, style: AutoLoopStyle.exact);
      final direct = AutoLoopAnalyzer.analyze(
          values: song, peaksPerSecond: 100, settings: settings);
      final viaInput = runAutoLoopAnalysis(AutoLoopInput(
          values: song, peaksPerSecond: 100, settings: settings));
      expect(viaInput.best!.startMs, direct.best!.startMs);
      expect(viaInput.best!.endMs, direct.best!.endMs);
    });
  });

  group('AutoLoopSettings', () {
    test('defaults', () {
      const s = AutoLoopSettings();
      expect(s.targetMs, AutoLoopSettings.defaultTargetMs);
      expect(s.style, AutoLoopStyle.beat);
    });

    test('normalized keeps the target inside the allowed range', () {
      expect(const AutoLoopSettings(targetMs: 100).normalized().targetMs,
          AutoLoopSettings.minTargetMs);
      expect(const AutoLoopSettings(targetMs: 999999).normalized().targetMs,
          AutoLoopSettings.maxTargetMs);
      expect(const AutoLoopSettings(targetMs: 30000).normalized().targetMs,
          30000);
    });

    test('JSON round trip', () {
      const s = AutoLoopSettings(targetMs: 25000, style: AutoLoopStyle.energy);
      final back = AutoLoopSettings.fromJson(s.toJson());
      expect(back.targetMs, 25000);
      expect(back.style, AutoLoopStyle.energy);
    });

    test('damaged or missing JSON gives defaults and never throws', () {
      for (final bad in [null, '', 'not json', '[1,2]', '{"targetMs":"x"}']) {
        final s = AutoLoopSettings.fromJson(bad);
        expect(s.targetMs, AutoLoopSettings.defaultTargetMs, reason: '$bad');
        expect(s.style, AutoLoopStyle.beat, reason: '$bad');
      }
    });

    test('unknown style name and out-of-range target are repaired', () {
      final s = AutoLoopSettings.fromJson('{"targetMs":1,"style":"jazz"}');
      expect(s.style, AutoLoopStyle.beat);
      expect(s.targetMs, AutoLoopSettings.minTargetMs);
    });
  });
}
