import 'auto_loop_config.dart';

/// Why Auto Loop found nothing. [PRD FR-038]
enum AutoLoopFailure {
  /// The song is shorter than the wanted loop (or shorter than a few seconds).
  tooShort,

  /// The waveform is (almost) completely silent.
  silent,

  /// Regions were tried but none sounded alike enough at both ends.
  noGoodLoop,
}

/// One suggested region.
class AutoLoopCandidate {
  const AutoLoopCandidate({
    required this.startMs,
    required this.endMs,
    required this.confidence,
  });

  final int startMs;
  final int endMs;

  /// 0.0 .. 1.0. A rough score of how alike the music sounds at both ends
  /// (plus beat / quiet-point fit). It is NOT a promise of a smooth loop.
  final double confidence;

  int get durationMs => endMs - startMs;
}

/// The answer of the analysis. Either [found] with a [best] suggestion, or
/// not found with a [failure] reason.
class AutoLoopResult {
  const AutoLoopResult.found({
    required AutoLoopCandidate this.best,
    this.alternatives = const [],
    required AutoLoopStyle this.styleUsed,
    this.fellBackToEnergy = false,
    this.estimatedBpm,
  }) : failure = null;

  const AutoLoopResult.failed(
    AutoLoopFailure this.failure, {
    this.estimatedBpm,
  })  : best = null,
        alternatives = const [],
        styleUsed = null,
        fellBackToEnergy = false;

  final AutoLoopCandidate? best;

  /// Other reasonable regions (their Start is at least 2 s from the best).
  final List<AutoLoopCandidate> alternatives;

  final AutoLoopFailure? failure;

  /// The style that was really used (can differ from the one asked for).
  final AutoLoopStyle? styleUsed;

  /// True when Beat-aligned was asked for but no clear beat was found, so
  /// quiet-point placement was used instead.
  final bool fellBackToEnergy;

  /// Estimated tempo, or null when no clear beat was detected. An estimate.
  final double? estimatedBpm;

  bool get found => best != null;
}
