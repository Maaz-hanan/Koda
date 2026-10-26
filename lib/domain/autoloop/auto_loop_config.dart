import 'dart:convert';

/// Which kind of loop Auto Loop should look for. [PRD FR-034]
enum AutoLoopStyle {
  /// As close to the target duration as possible (exactly the target).
  exact,

  /// Start and End snapped to an ESTIMATED beat grid.
  beat,

  /// Start and End placed at quiet points (phrase-like boundaries).
  energy,
}

/// Every number that shapes the analysis lives here, so tuning after you
/// try it on real songs means editing this one file.
///
/// Times are in milliseconds and are converted to "number of waveform
/// values" inside the analyzer, so the analysis does not depend on the
/// waveform having exactly 100 values per second.
///
/// IMPORTANT: these were chosen on synthetic test songs. They have NOT been
/// tuned on real music yet.
class AutoLoopTuning {
  AutoLoopTuning._();

  // --- Envelope ---
  static const int smoothMs = 50; // loudness smoothing
  static const int onsetLagMs = 30; // "how much louder than 30 ms ago?"
  static const double silenceFloor = 0.02; // below this counts as quiet

  // --- Beat estimate ---
  static const int bpmMin = 60;
  static const int bpmMax = 180;
  static const double beatMinStrength = 0.20; // below: "no clear beat"
  static const int beatMinAnalysisMs = 8000; // too short to judge a beat
  static const int beatMaxAnalysisMs = 600000; // only first 10 min are used

  // --- Candidate scoring ---
  static const int contextMs = 400; // sound compared around each boundary
  static const int contextBins = 8;
  static const double maxQuietFraction = 0.4; // more silence than this: reject
  static const double minSimilarity = 0.30; // boundaries too different: reject
  static const double minConfidence = 0.55; // below: "no good loop found"

  // --- Candidate search ---
  static const int exactStepMs = 100; // exact style tries every 100 ms
  static const int peakSmoothMs = 210; // smoothing used to find quiet points
  static const int minPeakSeparationMs = 300;
  static const int minSongMs = 6000;
  static const int minToleranceMs = 2000; // beat/energy: target +/- this, or
  static const double toleranceFraction = 0.25; // +/- 25% (whichever is more)
  static const int alternativeGapMs = 2000;
  static const int maxAlternatives = 2;

  // --- Score weights (each style's weights add up to 1.0) ---
  // similarity / quiet-boundary / content / beat / duration
  static const double exactSim = 0.55, exactDip = 0.15, exactContent = 0.30;
  static const double beatSim = 0.35,
      beatBeat = 0.30,
      beatDip = 0.10,
      beatContent = 0.15,
      beatDuration = 0.10;
  static const double energySim = 0.35,
      energyDip = 0.35,
      energyContent = 0.15,
      energyDuration = 0.15;
}

/// What the user asked Auto Loop for. Can be stored as JSON in the
/// existing `autoLoopPrefsJson` column. [PRD FR-033, FR-034]
class AutoLoopSettings {
  const AutoLoopSettings({
    this.targetMs = defaultTargetMs,
    this.style = AutoLoopStyle.beat,
  });

  static const int defaultTargetMs = 20000;
  static const int minTargetMs = 5000;
  static const int maxTargetMs = 60000;
  static const int targetStepMs = 5000;

  /// Wanted loop length in milliseconds.
  final int targetMs;
  final AutoLoopStyle style;

  /// A copy whose target is inside [minTargetMs]..[maxTargetMs].
  AutoLoopSettings normalized() => AutoLoopSettings(
        targetMs: targetMs.clamp(minTargetMs, maxTargetMs).toInt(),
        style: style,
      );

  AutoLoopSettings copyWith({int? targetMs, AutoLoopStyle? style}) =>
      AutoLoopSettings(
        targetMs: targetMs ?? this.targetMs,
        style: style ?? this.style,
      );

  String toJson() => jsonEncode({
        'v': 1,
        'targetMs': targetMs,
        'style': style.name,
      });

  /// Reads settings back. Never throws: anything missing, damaged or out of
  /// range gives the default (or the nearest allowed value).
  factory AutoLoopSettings.fromJson(String? json) {
    if (json == null || json.isEmpty) return const AutoLoopSettings();
    try {
      final map = jsonDecode(json);
      if (map is! Map) return const AutoLoopSettings();
      final target = map['targetMs'];
      final styleName = map['style'];
      return AutoLoopSettings(
        targetMs: target is num ? target.round() : defaultTargetMs,
        style: AutoLoopStyle.values.firstWhere(
          (s) => s.name == styleName,
          orElse: () => AutoLoopStyle.beat,
        ),
      ).normalized();
    } catch (_) {
      return const AutoLoopSettings();
    }
  }
}
