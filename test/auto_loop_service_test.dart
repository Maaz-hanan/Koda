import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/services/auto_loop_service.dart';
import 'package:loop_player/domain/autoloop/auto_loop_analyzer.dart';
import 'package:loop_player/domain/autoloop/auto_loop_config.dart';
import 'package:loop_player/domain/autoloop/auto_loop_result.dart';
import 'package:loop_player/domain/autoloop/auto_loop_runner.dart';
import 'package:loop_player/domain/waveform/waveform_loader.dart';
import 'package:loop_player/domain/waveform/waveform_peaks.dart';

/// A fake waveform source: no audio file needed.
class FakeWaveformLoader implements WaveformLoader {
  FakeWaveformLoader({this.peaks, this.error});

  final WaveformPeaks? peaks;
  final Object? error;
  String? askedFor;

  @override
  Future<WaveformPeaks> load(
    String songId, {
    void Function(double progress)? onProgress,
  }) async {
    askedFor = songId;
    onProgress?.call(0.5);
    if (error != null) throw error!;
    return peaks!;
  }
}

/// A fake song: a loud burst on every beat.
WaveformPeaks clickPeaks(double seconds, double bpm) {
  final n = (seconds * 100).floor();
  final v = List<double>.filled(n, 0.03);
  final period = 60 / bpm * 100;
  for (var k = 0;; k++) {
    final t = (k * period).round();
    if (t >= n) break;
    final a = 0.9 * (k % 4 == 0 ? 1.0 : 0.7);
    for (var j = 0; j < 26; j++) {
      if (t + j < n) {
        final value = a * math.pow(0.85, j).toDouble();
        if (value > v[t + j]) v[t + j] = value;
      }
    }
  }
  return WaveformPeaks(values: v, peaksPerSecond: 100);
}

/// Runs the analysis on the spot (no isolate), so tests are quick.
Future<AutoLoopResult> inline(AutoLoopInput input) async =>
    runAutoLoopAnalysis(input);

void main() {
  group('AutoLoopService (analysis run directly)', () {
    test('asks for the right song and returns a suggestion', () async {
      final loader = FakeWaveformLoader(peaks: clickPeaks(60, 120));
      final service = AutoLoopService(loader, analyse: inline);

      final result = await service.run(
        'song-1',
        const AutoLoopSettings(targetMs: 16000, style: AutoLoopStyle.exact),
      );

      expect(loader.askedFor, 'song-1');
      expect(result.found, isTrue);
      expect(result.best!.durationMs, 16000);
    });

    test('reports both stages in order and the waveform progress', () async {
      final service = AutoLoopService(
        FakeWaveformLoader(peaks: clickPeaks(30, 120)),
        analyse: inline,
      );
      final stages = <AutoLoopStage>[];
      final progress = <double>[];

      await service.run(
        's',
        const AutoLoopSettings(),
        onStage: stages.add,
        onWaveformProgress: progress.add,
      );

      expect(stages,
          [AutoLoopStage.preparingWaveform, AutoLoopStage.analysing]);
      expect(progress, [0.5]);
    });

    test('hands the analysis a normalized target', () async {
      AutoLoopInput? seen;
      final service = AutoLoopService(
        FakeWaveformLoader(peaks: clickPeaks(30, 120)),
        analyse: (input) async {
          seen = input;
          return runAutoLoopAnalysis(input);
        },
      );

      await service.run('s', const AutoLoopSettings(targetMs: 999999));

      expect(seen!.settings.targetMs, AutoLoopSettings.maxTargetMs);
      expect(seen!.peaksPerSecond, 100);
    });

    test('a song with no good loop is a normal result, not an exception',
        () async {
      final service = AutoLoopService(
        FakeWaveformLoader(
            peaks: WaveformPeaks(
                values: List<double>.filled(6000, 0.0), peaksPerSecond: 100)),
        analyse: inline,
      );

      final result = await service.run('s', const AutoLoopSettings());

      expect(result.found, isFalse);
      expect(result.failure, AutoLoopFailure.silent);
    });

    test('a waveform problem becomes an AutoLoopException with its message',
        () async {
      final service = AutoLoopService(
        FakeWaveformLoader(error: WaveformException('The audio file for this song is missing.')),
        analyse: inline,
      );

      await expectLater(
        service.run('s', const AutoLoopSettings()),
        throwsA(isA<AutoLoopException>().having(
            (e) => e.message, 'message', 'The audio file for this song is missing.')),
      );
    });

    test('an unexpected waveform error becomes a safe message', () async {
      final service = AutoLoopService(
        FakeWaveformLoader(error: StateError('boom')),
        analyse: inline,
      );

      await expectLater(
        service.run('s', const AutoLoopSettings()),
        throwsA(isA<AutoLoopException>()
            .having((e) => e.message, 'message', isNot(contains('boom')))),
      );
    });

    test('a crash inside the analysis becomes a safe message', () async {
      final service = AutoLoopService(
        FakeWaveformLoader(peaks: clickPeaks(30, 120)),
        analyse: (input) async => throw StateError('boom'),
      );

      await expectLater(
        service.run('s', const AutoLoopSettings()),
        throwsA(isA<AutoLoopException>()
            .having((e) => e.message, 'message', isNot(contains('boom')))),
      );
    });
  });

  group('AutoLoopService (real background isolate)', () {
    test('compute() accepts the input and gives back a result', () async {
      // Uses the default analysis: compute(runAutoLoopAnalysis, input).
      // This proves the data can really cross to another isolate and back.
      final service =
          AutoLoopService(FakeWaveformLoader(peaks: clickPeaks(40, 120)));

      final result = await service.run(
        's',
        const AutoLoopSettings(targetMs: 10000, style: AutoLoopStyle.exact),
      );

      expect(result.found, isTrue);
      expect(result.best!.durationMs, 10000);
    });
  });
}
