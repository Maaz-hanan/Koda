import 'dart:convert';

import '../../data/models/song.dart';

/// What we remember about playback between app launches. [PRD FR-011]
///
/// Only plain data (IDs and a number). No audio objects, so it can be
/// unit-tested without a phone.
class SavedPlayback {
  const SavedPlayback({
    required this.queueIds,
    required this.currentId,
    required this.positionMs,
  });

  /// IDs of the songs in the queue, in order.
  final List<String> queueIds;

  /// ID of the song that was current.
  final String currentId;

  /// Where we were in that song, in milliseconds.
  final int positionMs;

  String toJsonString() => jsonEncode({
        'v': 1,
        'queue': queueIds,
        'current': currentId,
        'positionMs': positionMs,
      });

  /// Returns null for anything that is missing, damaged or not ours.
  static SavedPlayback? tryParse(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final data = jsonDecode(text);
      if (data is! Map) return null;
      final queue = data['queue'];
      final current = data['current'];
      final pos = data['positionMs'];
      if (queue is! List || current is! String || pos is! int) return null;
      if (queue.any((e) => e is! String)) return null;
      return SavedPlayback(
        queueIds: queue.cast<String>(),
        currentId: current,
        positionMs: pos < 0 ? 0 : pos,
      );
    } catch (_) {
      return null;
    }
  }
}

/// The queue we can actually rebuild from the saved data.
class RestoredQueue {
  const RestoredQueue({
    required this.songs,
    required this.startIndex,
    required this.positionMs,
  });

  final List<Song> songs;
  final int startIndex;
  final int positionMs;
}

/// Matches saved IDs against the songs that still exist in the library.
///
/// * Songs removed since the last launch are dropped from the queue.
/// * If the saved CURRENT song was removed, nothing is restored (null) —
///   we don't guess a different song.
RestoredQueue? resolveRestore(SavedPlayback saved, List<Song> library) {
  final byId = {for (final s in library) s.id: s};

  final songs = <Song>[];
  for (final id in saved.queueIds) {
    final song = byId[id];
    if (song != null) songs.add(song);
  }

  final index = songs.indexWhere((s) => s.id == saved.currentId);
  if (index < 0) return null;

  return RestoredQueue(
    songs: songs,
    startIndex: index,
    positionMs: saved.positionMs,
  );
}
