import 'auto_loop_config.dart';
import 'auto_loop_result.dart';

/// Which part of the work is running right now. The loop editor uses this
/// to show the right loading text. [PRD FR-039]
enum AutoLoopStage {
  /// Reading the song's waveform (made first if it does not exist yet).
  preparingWaveform,

  /// Looking for a loop in the waveform (runs on a background isolate).
  analysing,
}

/// Something went wrong while running Auto Loop (as opposed to "ran fine,
/// but found no good loop", which is a normal [AutoLoopResult]).
/// [message] is safe to show to the user. [PRD FR-039]
class AutoLoopException implements Exception {
  AutoLoopException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Anything that can run Auto Loop for a song. The real one lives in
/// lib/data/services/auto_loop_service.dart; tests use a fake.
abstract class AutoLoopRunner {
  /// Finds a loop for [songId].
  ///
  /// Never writes to the database. Throws [AutoLoopException] (message safe
  /// to show) when the song cannot be read or the analysis crashes.
  Future<AutoLoopResult> run(
    String songId,
    AutoLoopSettings settings, {
    void Function(AutoLoopStage stage)? onStage,
    void Function(double progress)? onWaveformProgress,
  });
}
