import 'dart:async';

import 'package:flutter/services.dart';

/// The app's vibration "taps". One place, so every screen feels the same.
///
/// Three strengths, like the iPhone's own apps:
///  * [tick]   a very light tick: small choices (buttons, steps, a row moving).
///  * [light]  a soft tap: something was done or confirmed (added, saved,
///             dropped, play / pause).
///  * [medium] a firmer tap: picking something up, opening something, or a
///             removal the user just confirmed.
///
/// Never throws and never waits: if the phone has no haptic engine (or the
/// call fails) nothing happens.
class Haptics {
  const Haptics._();

  static void tick() => _fire(HapticFeedback.selectionClick);
  static void light() => _fire(HapticFeedback.lightImpact);
  static void medium() => _fire(HapticFeedback.mediumImpact);

  static void _fire(Future<void> Function() haptic) {
    try {
      unawaited(haptic().catchError((Object _) {}));
    } catch (_) {}
  }
}
