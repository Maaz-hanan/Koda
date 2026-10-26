import 'package:flutter/foundation.dart';

import '../../domain/autoloop/auto_loop_analyzer.dart';
import '../../domain/autoloop/auto_loop_config.dart';
import '../../domain/autoloop/auto_loop_result.dart';
import '../../domain/autoloop/auto_loop_runner.dart';
import '../../domain/waveform/waveform_loader.dart';
import '../../domain/waveform/waveform_peaks.dart';

/// Runs Auto Loop: gets the song's waveform (cached, so usually instant),
/// then does the analysis on a background isolate with `compute()` so the
/// screen never freezes. [PRD FR-035, FR-039]
///
/// It only READS. It never touches the database; saving is the editor's job
/// when the user presses Save. [PRD FR-037]
class AutoLoopService implements AutoLoopRunner {
  /// [analyse] exists so tests can run the analysis without an isolate.
  /// The app uses the default: `compute(runAutoLoopAnalysis, input)`.
  AutoLoopService(
    this._waveforms, {
    Future<AutoLoopResult> Function(AutoLoopInput input)? analyse,
  }) : _analyse = analyse ?? _analyseInBackground;

  final WaveformLoader _waveforms;
  final Future<AutoLoopResult> Function(AutoLoopInput input) _analyse;

  static Future<AutoLoopResult> _analyseInBackground(AutoLoopInput input) =>
      compute(runAutoLoopAnalysis, input);

  @override
  Future<AutoLoopResult> run(
    String songId,
    AutoLoopSettings settings, {
    void Function(AutoLoopStage stage)? onStage,
    void Function(double progress)? onWaveformProgress,
  }) async {
    onStage?.call(AutoLoopStage.preparingWaveform);
    final peaks = await _loadPeaks(songId, onWaveformProgress);

    onStage?.call(AutoLoopStage.analysing);
    try {
      return await _analyse(AutoLoopInput(
        values: peaks.values,
        peaksPerSecond: peaks.peaksPerSecond,
        settings: settings.normalized(),
      ));
    } catch (_) {
      throw AutoLoopException("Auto Loop couldn't analyse this song.");
    }
  }

  Future<WaveformPeaks> _loadPeaks(
    String songId,
    void Function(double progress)? onProgress,
  ) async {
    try {
      return await _waveforms.load(songId, onProgress: onProgress);
    } on WaveformException catch (e) {
      throw AutoLoopException(e.message);
    } catch (_) {
      throw AutoLoopException("Couldn't read this song to look for a loop.");
    }
  }
}
