import 'dart:math' as math;

import '../loop/loop_region.dart';
import 'auto_loop_config.dart';
import 'auto_loop_result.dart';

/// Everything the analysis needs, in a form that can be handed to another
/// isolate (for example with Flutter's `compute`). [PRD FR-035]
class AutoLoopInput {
  const AutoLoopInput({
    required this.values,
    required this.peaksPerSecond,
    required this.settings,
  });

  /// Loudness per slice of time, 0.0 .. 1.0 (WaveformPeaks.values).
  final List<double> values;

  /// How many [values] make up one second (WaveformPeaks.peaksPerSecond).
  final double peaksPerSecond;

  final AutoLoopSettings settings;
}

/// Top-level function so it can run in a background isolate:
/// `compute(runAutoLoopAnalysis, input)`.
AutoLoopResult runAutoLoopAnalysis(AutoLoopInput input) =>
    AutoLoopAnalyzer.analyze(
      values: input.values,
      peaksPerSecond: input.peaksPerSecond,
      settings: input.settings,
    );

/// Looks for a good loop region using ONLY the loudness waveform.
///
/// What it does, in plain words:
///  1. Smooths the loudness into a "level" curve.
///  2. Finds onsets: moments where the level jumps up (a note or beat).
///  3. Estimates the tempo from how regularly onsets repeat (60..180 BPM).
///     If they are not regular, the song counts as "no clear beat".
///  4. Tries many Start/End pairs near the target length and scores each by
///     how alike the sound is around both boundaries, how quiet the
///     boundaries are, whether the region is more than silence and (Beat
///     style) whether the boundaries sit on the estimated beat grid.
///  5. Returns the best one with a confidence, or says nothing good was found.
///
/// Honest limits: a loudness curve has no pitch, harmony or lyrics, so this
/// cannot hear whether a jump will sound musical. Beat positions are
/// estimates and get worse when the tempo drifts. Always preview.
class AutoLoopAnalyzer {
  AutoLoopAnalyzer._();

  static AutoLoopResult analyze({
    required List<double> values,
    required double peaksPerSecond,
    required AutoLoopSettings settings,
  }) {
    final s = settings.normalized();
    final pps = peaksPerSecond;
    final n = values.length;
    if (n == 0 || pps <= 0) {
      return const AutoLoopResult.failed(AutoLoopFailure.tooShort);
    }

    int fr(int ms) => math.max(1, (ms * pps / 1000).round());

    final durationMs = n * 1000 / pps;
    final tf = fr(s.targetMs); // target length in values
    final tol = math.max(
      fr(AutoLoopTuning.minToleranceMs),
      (tf * AutoLoopTuning.toleranceFraction).floor(),
    );

    // Even the shortest allowed region must fit inside the song.
    final shortestNeeded = s.style == AutoLoopStyle.exact ? tf : tf - tol;
    if (durationMs < AutoLoopTuning.minSongMs || n < shortestNeeded) {
      return const AutoLoopResult.failed(AutoLoopFailure.tooShort);
    }

    final ctx = _Ctx(values, pps);
    if (ctx.songLevelNonSilent <= 0) {
      return const AutoLoopResult.failed(AutoLoopFailure.silent);
    }

    final beat = _detectBeat(ctx.onset, pps);
    final bpm = beat?.bpm;

    var used = s.style;
    var fellBack = false;
    if (used == AutoLoopStyle.beat && beat == null) {
      used = AutoLoopStyle.energy;
      fellBack = true;
    }

    final cands = <_Cand>[];

    void add(int a, int e, {double beatScore = 0.0, double durScore = 1.0}) {
      final p = _parts(ctx, a, e);
      if (p.similarity < AutoLoopTuning.minSimilarity || p.content <= 0) return;
      final double score = switch (used) {
        AutoLoopStyle.exact => AutoLoopTuning.exactSim * p.similarity +
            AutoLoopTuning.exactDip * p.dip +
            AutoLoopTuning.exactContent * p.content,
        AutoLoopStyle.beat => AutoLoopTuning.beatSim * p.similarity +
            AutoLoopTuning.beatBeat * beatScore +
            AutoLoopTuning.beatDip * p.dip +
            AutoLoopTuning.beatContent * p.content +
            AutoLoopTuning.beatDuration * durScore,
        AutoLoopStyle.energy => AutoLoopTuning.energySim * p.similarity +
            AutoLoopTuning.energyDip * p.dip +
            AutoLoopTuning.energyContent * p.content +
            AutoLoopTuning.energyDuration * durScore,
      };
      cands.add(_Cand(score.clamp(0.0, 1.0).toDouble(), a, e));
    }

    switch (used) {
      case AutoLoopStyle.exact:
        final step = fr(AutoLoopTuning.exactStepMs);
        for (var a = 0; a + tf <= n; a += step) {
          add(a, a + tf);
        }
      case AutoLoopStyle.energy:
        final points = _quietPoints(ctx, pps);
        for (var i = 0; i < points.length; i++) {
          final a = points[i];
          for (var j = i + 1; j < points.length; j++) {
            final e = points[j];
            final d = e - a;
            if (d > tf + tol) break;
            if (d < tf - tol) continue;
            add(a, e, durScore: 1.0 - (d - tf).abs() / tol);
          }
        }
      case AutoLoopStyle.beat:
        final b = beat!; // not null: we fell back above otherwise
        final grid = <int>[];
        for (var k = 0;; k++) {
          final t = (b.phase + k * b.period).round();
          if (t >= n) break;
          grid.add(t);
        }
        final minBeats = math.max(1, ((tf - tol) / b.period).ceil());
        final maxBeats = ((tf + tol) / b.period).floor();
        for (var i = 0; i < grid.length; i++) {
          final a = grid[i];
          for (var m = minBeats; m <= maxBeats; m++) {
            if (i + m >= grid.length) break;
            final e = grid[i + m];
            final presence =
                0.5 * (ctx.onsetPresence(a) + ctx.onsetPresence(e));
            // Whole bars (4 beats) are slightly preferred.
            final beatScore = 0.8 * presence + (m % 4 == 0 ? 0.2 : 0.0);
            add(a, e,
                beatScore: beatScore,
                durScore: 1.0 - ((e - a) - tf).abs() / tol);
          }
        }
    }

    if (cands.isEmpty) {
      return AutoLoopResult.failed(AutoLoopFailure.noGoodLoop,
          estimatedBpm: bpm);
    }

    // Best first; equal scores: the earlier region.
    cands.sort((x, y) {
      final c = y.score.compareTo(x.score);
      return c != 0 ? c : x.start.compareTo(y.start);
    });

    final top = cands.first;
    if (top.score < AutoLoopTuning.minConfidence) {
      return AutoLoopResult.failed(AutoLoopFailure.noGoodLoop,
          estimatedBpm: bpm);
    }

    final lastMs = (durationMs ~/ LoopRegion.dragStepMs) * LoopRegion.dragStepMs;
    AutoLoopCandidate toCandidate(_Cand c) {
      final startMs = LoopRegion.snap((c.start * 1000 / pps).round());
      var endMs = LoopRegion.snap((c.end * 1000 / pps).round());
      if (endMs > lastMs) endMs = lastMs;
      return AutoLoopCandidate(
          startMs: startMs, endMs: endMs, confidence: c.score);
    }

    // A couple of other options whose Start is clearly elsewhere.
    final gap = fr(AutoLoopTuning.alternativeGapMs);
    final chosen = <_Cand>[top];
    for (final c in cands) {
      if (chosen.length > AutoLoopTuning.maxAlternatives) break;
      if (c.score < AutoLoopTuning.minConfidence) break;
      if (chosen.every((o) => (o.start - c.start).abs() >= gap)) {
        chosen.add(c);
      }
    }

    return AutoLoopResult.found(
      best: toCandidate(chosen.first),
      alternatives: chosen.skip(1).map(toCandidate).toList(growable: false),
      styleUsed: used,
      fellBackToEnergy: fellBack,
      estimatedBpm: bpm,
    );
  }

  // ---------------------------------------------------------------------
  // Beat estimate
  // ---------------------------------------------------------------------

  /// Most regular spacing of onsets between bpmMin and bpmMax, or null when
  /// the pattern is not regular enough (or the song is too short).
  static _Beat? _detectBeat(List<double> onset, double pps) {
    final total = onset.length;
    if (total < pps * AutoLoopTuning.beatMinAnalysisMs / 1000) return null;

    final n = math.min(
      total,
      (pps * AutoLoopTuning.beatMaxAnalysisMs / 1000).round(),
    );

    var mean = 0.0;
    for (var i = 0; i < n; i++) {
      mean += onset[i];
    }
    mean /= n;
    final x = List<double>.generate(n, (i) => onset[i] - mean);
    var r0 = 0.0;
    for (final v in x) {
      r0 += v * v;
    }
    if (r0 <= 1e-12) return null;

    final lagMin = math.max(2, (pps * 60 / AutoLoopTuning.bpmMax).ceil());
    final lagMax = (pps * 60 / AutoLoopTuning.bpmMin).floor();
    if (lagMax <= lagMin || lagMax + 1 >= n) return null;

    // r[lag] = how much the onset curve resembles itself shifted by lag.
    final r = List<double>.filled(lagMax + 2, 0.0);
    for (var lag = lagMin - 1; lag <= lagMax + 1; lag++) {
      var sum = 0.0;
      for (var i = 0; i < n - lag; i++) {
        sum += x[i] * x[i + lag];
      }
      r[lag] = sum / r0;
    }

    var best = lagMin;
    for (var lag = lagMin + 1; lag <= lagMax; lag++) {
      if (r[lag] > r[best] + 1e-9) best = lag;
    }
    if (r[best] < AutoLoopTuning.beatMinStrength) return null;

    // Sub-value precision with a parabola through the three nearest points.
    var period = best.toDouble();
    final a = r[best - 1];
    final b = r[best];
    final c = r[best + 1];
    final den = a - 2 * b + c;
    if (den.abs() > 1e-12) {
      final shift = 0.5 * (a - c) / den;
      if (shift.abs() <= 1.0) period = best + shift;
    }

    // Phase: where in the first period the beats fall (strongest onsets).
    final phases = period.ceil();
    var bestPhase = 0;
    var bestScore = -1.0;
    for (var ph = 0; ph < phases; ph++) {
      var score = 0.0;
      for (var k = 0;; k++) {
        final t = (ph + k * period).round();
        if (t >= total) break;
        var peak = 0.0;
        final lo = math.max(0, t - 1);
        final hi = math.min(total - 1, t + 1);
        for (var i = lo; i <= hi; i++) {
          if (onset[i] > peak) peak = onset[i];
        }
        score += peak;
      }
      if (score > bestScore) {
        bestScore = score;
        bestPhase = ph;
      }
    }

    return _Beat(
      period: period,
      phase: bestPhase,
      bpm: 60 * pps / period,
    );
  }

  // ---------------------------------------------------------------------
  // Quiet points (Energy style)
  // ---------------------------------------------------------------------

  /// Positions of local loudness dips, at least minPeakSeparationMs apart
  /// (the quietest ones win), in time order.
  static List<int> _quietPoints(_Ctx ctx, double pps) {
    final n = ctx.n;
    final halfWindow =
        math.max(1, (AutoLoopTuning.peakSmoothMs * pps / 2000).floor());
    final smooth = _box(ctx.level, 2 * halfWindow + 1);

    final minima = <int>[];
    for (var i = 1; i < n - 1; i++) {
      if (smooth[i] <= smooth[i - 1] && smooth[i] < smooth[i + 1]) {
        minima.add(i);
      }
    }
    minima.sort((p, q) {
      final c = smooth[p].compareTo(smooth[q]);
      return c != 0 ? c : p.compareTo(q);
    });

    final separation =
        math.max(1, (AutoLoopTuning.minPeakSeparationMs * pps / 1000).round());
    final keep = <int>[];
    for (final i in minima) {
      var ok = true;
      for (final j in keep) {
        if ((i - j).abs() < separation) {
          ok = false;
          break;
        }
      }
      if (ok) keep.add(i);
    }
    keep.sort();
    return keep;
  }

  // ---------------------------------------------------------------------
  // Scoring a Start/End pair
  // ---------------------------------------------------------------------

  static _Parts _parts(_Ctx c, int a, int e) {
    final ctxLen = c.contextLen;
    final similarity = 0.5 *
        (_similarity(c.bins(a - ctxLen, a), c.bins(e - ctxLen, e)) +
            _similarity(c.bins(a, a + ctxLen), c.bins(e, e + ctxLen)));

    final regionMean = c.mean(a, e);

    // Quiet boundaries: 1 = silent, 0 = as loud as the region's average.
    final dip = 0.5 *
        ((1 - math.min(1.0, c.levelAt(a) / (regionMean + 1e-6))) +
            (1 - math.min(1.0, c.levelAt(e) / (regionMean + 1e-6))));

    // Content: reject regions that are mostly silence, and regions much
    // quieter than the rest of the song.
    final quiet = c.quietFraction(a, e);
    final double content;
    if (c.songLevelNonSilent <= 0 || quiet > AutoLoopTuning.maxQuietFraction) {
      content = 0.0;
    } else {
      content = math.min(1.0, regionMean / (0.7 * c.songLevelNonSilent)) *
          math.max(0.0, 1 - quiet * 2);
    }

    return _Parts(similarity, dip, content);
  }

  /// 1.0 = identical shape and level, 0.0 = completely different.
  static double _similarity(List<double> p, List<double> q) {
    var diff = 0.0;
    var total = 0.0;
    for (var i = 0; i < p.length; i++) {
      diff += (p[i] - q[i]).abs();
      total += p[i] + q[i];
    }
    return math.max(0.0, 1 - diff / (total + 1e-6));
  }

  // ---------------------------------------------------------------------
  // Small helpers
  // ---------------------------------------------------------------------

  /// Moving average over [width] values (odd), shrinking at the edges.
  static List<double> _box(List<double> v, int width) {
    final n = v.length;
    final prefix = List<double>.filled(n + 1, 0.0);
    for (var i = 0; i < n; i++) {
      prefix[i + 1] = prefix[i] + v[i];
    }
    final half = width ~/ 2;
    final out = List<double>.filled(n, 0.0);
    for (var i = 0; i < n; i++) {
      final lo = math.max(0, i - half);
      final hi = math.min(n, i + half + 1);
      out[i] = (prefix[hi] - prefix[lo]) / (hi - lo);
    }
    return out;
  }
}

/// Precomputed curves shared by all candidates.
class _Ctx {
  _Ctx(List<double> values, double pps) : n = values.length {
    final half = math.max(1, (AutoLoopTuning.smoothMs * pps / 2000).floor());
    level = AutoLoopAnalyzer._box(values, 2 * half + 1);

    // Onset strength: how much louder than a moment ago (never negative),
    // scaled so the strongest onset is 1.0.
    final lag = math.max(1, (AutoLoopTuning.onsetLagMs * pps / 1000).round());
    onset = List<double>.filled(n, 0.0);
    var maxOnset = 0.0;
    for (var i = lag; i < n; i++) {
      final d = level[i] - level[i - lag];
      if (d > 0) {
        onset[i] = d;
        if (d > maxOnset) maxOnset = d;
      }
    }
    if (maxOnset > 0) {
      for (var i = 0; i < n; i++) {
        onset[i] /= maxOnset;
      }
    }

    // Running totals so "average level between a and b" is instant.
    _sum = List<double>.filled(n + 1, 0.0);
    _quiet = List<int>.filled(n + 1, 0);
    var loudSum = 0.0;
    var loudCount = 0;
    for (var i = 0; i < n; i++) {
      _sum[i + 1] = _sum[i] + level[i];
      final isQuiet = level[i] < AutoLoopTuning.silenceFloor;
      _quiet[i + 1] = _quiet[i] + (isQuiet ? 1 : 0);
      if (!isQuiet) {
        loudSum += level[i];
        loudCount++;
      }
    }
    songLevelNonSilent = loudCount == 0 ? 0.0 : loudSum / loudCount;

    contextLen = math.max(
      AutoLoopTuning.contextBins,
      (AutoLoopTuning.contextMs * pps / 1000).round(),
    );
  }

  final int n;
  late final List<double> level;
  late final List<double> onset;
  late final List<double> _sum;
  late final List<int> _quiet;
  late final double songLevelNonSilent;
  late final int contextLen;

  double mean(int a, int b) {
    final lo = math.max(0, a);
    final hi = math.min(n, b);
    return hi > lo ? (_sum[hi] - _sum[lo]) / (hi - lo) : 0.0;
  }

  double quietFraction(int a, int b) {
    final lo = math.max(0, a);
    final hi = math.min(n, b);
    return hi > lo ? (_quiet[hi] - _quiet[lo]) / (hi - lo) : 1.0;
  }

  /// Level right around position [t] (about 5 values).
  double levelAt(int t) => mean(t - 2, t + 3);

  /// 0..1: is there an onset at (or right next to) [t]?
  double onsetPresence(int t) {
    var peak = 0.0;
    final lo = math.max(0, t - 2);
    final hi = math.min(n - 1, t + 2);
    for (var i = lo; i <= hi; i++) {
      if (onset[i] > peak) peak = onset[i];
    }
    return math.min(1.0, 2 * peak);
  }

  /// The level between [a] and [b], squeezed into a few bars. Values outside
  /// the song count as silence.
  List<double> bins(int a, int b) {
    final count = AutoLoopTuning.contextBins;
    final out = List<double>.filled(count, 0.0);
    final width = (b - a) / count;
    for (var k = 0; k < count; k++) {
      final lo = (a + k * width).round();
      final hi = (a + (k + 1) * width).round();
      final end = math.max(hi, lo + 1);
      var sum = 0.0;
      var c = 0;
      for (var i = lo; i < end; i++) {
        if (i >= 0 && i < n) sum += level[i];
        c++;
      }
      out[k] = sum / c;
    }
    return out;
  }
}

class _Beat {
  const _Beat({required this.period, required this.phase, required this.bpm});

  /// Distance between beats, in waveform values (can be fractional).
  final double period;

  /// Position of the first beat, in waveform values.
  final int phase;
  final double bpm;
}

class _Parts {
  const _Parts(this.similarity, this.dip, this.content);
  final double similarity;
  final double dip;
  final double content;
}

class _Cand {
  const _Cand(this.score, this.start, this.end);
  final double score;
  final int start;
  final int end;
}
