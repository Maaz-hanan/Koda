import 'package:flutter/foundation.dart';

import '../../domain/loop/loop_mode.dart';

/// The SAVED loop settings for one song. [PRD FR-018, FR-019, FR-020]
///
/// This is only the saved "recipe". Things that change while music plays
/// (current repeat counter, position, etc.) belong in ActiveLoopSession
/// (Phase 3) and are never stored here.
@immutable
class LoopProfile {
  const LoopProfile({
    required this.songId,
    required this.mode,
    this.loopStartMs,
    this.loopEndMs,
    this.finiteCount,
    this.autoLoopPrefsJson,
    required this.updatedAt,
  });

  /// A profile meaning "no looping" for a song that has never been configured.
  factory LoopProfile.defaultFor(String songId) => LoopProfile(
        songId: songId,
        mode: LoopMode.off,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

  final String songId;
  final LoopMode mode;

  /// Section start/end in milliseconds. Null unless a section is configured.
  final int? loopStartMs;
  final int? loopEndMs;

  /// Total number of plays for a finite section loop.
  final int? finiteCount;

  final String? autoLoopPrefsJson;
  final int updatedAt;

  bool get isSectionMode =>
      mode == LoopMode.finiteSection || mode == LoopMode.infiniteSection;

  /// Returns an error message if the section is invalid, otherwise null.
  /// [PRD FR-024]
  String? validate({required int durationMs}) {
    if (!isSectionMode) return null;
    final start = loopStartMs;
    final end = loopEndMs;
    if (start == null || end == null) return 'Choose a start and end for the loop.';
    if (start < 0) return 'Loop start cannot be before the beginning of the song.';
    if (durationMs > 0 && end > durationMs) return 'Loop end is past the end of the song.';
    if (start >= end) return 'Loop start must be before loop end.';
    if (mode == LoopMode.finiteSection && (finiteCount == null || finiteCount! < 1)) {
      return 'Repeat count must be at least 1.';
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
        'song_id': songId,
        'mode': mode.name,
        'loop_start_ms': loopStartMs,
        'loop_end_ms': loopEndMs,
        'finite_count': finiteCount,
        'auto_loop_prefs_json': autoLoopPrefsJson,
        'updated_at': updatedAt,
      };

  factory LoopProfile.fromMap(Map<String, dynamic> map) => LoopProfile(
        songId: map['song_id'] as String,
        mode: LoopMode.values.firstWhere(
          (m) => m.name == map['mode'],
          orElse: () => LoopMode.off,
        ),
        loopStartMs: map['loop_start_ms'] as int?,
        loopEndMs: map['loop_end_ms'] as int?,
        finiteCount: map['finite_count'] as int?,
        autoLoopPrefsJson: map['auto_loop_prefs_json'] as String?,
        updatedAt: map['updated_at'] as int,
      );
}
