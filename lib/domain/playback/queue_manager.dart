import '../../data/models/song.dart';

/// Pure bookkeeping for "which songs are queued and which one is current".
/// No audio in here, so it can be unit-tested. [PRD FR-008]
///
/// Rules (predictable, per the PRD):
///  * Next on the last song does NOT wrap around (moveToNext returns false).
///  * Previous on the first song does not move (moveToPrevious returns false).
class QueueManager {
  List<Song> _songs = const [];
  int _index = -1;

  List<Song> get songs => _songs;

  /// Index of the current song, or -1 if nothing is current.
  int get index => _index;

  Song? get current =>
      (_index >= 0 && _index < _songs.length) ? _songs[_index] : null;

  bool get hasNext => _index >= 0 && _index < _songs.length - 1;
  bool get hasPrevious => _index > 0;

  void setQueue(List<Song> songs, int startIndex) {
    _songs = List.unmodifiable(songs);
    if (songs.isEmpty) {
      _index = -1;
    } else {
      _index = startIndex.clamp(0, songs.length - 1).toInt();
    }
  }

  bool moveToNext() {
    if (!hasNext) return false;
    _index++;
    return true;
  }

  bool moveToPrevious() {
    if (!hasPrevious) return false;
    _index--;
    return true;
  }

  /// Nothing is current any more (e.g. playback stopped).
  void clearCurrent() => _index = -1;

  /// Removes a song from the queue. Returns true if it was the CURRENT song
  /// (in which case nothing is current afterwards).
  bool remove(String songId) {
    final i = _songs.indexWhere((s) => s.id == songId);
    if (i < 0) return false;

    final wasCurrent = i == _index;
    final updated = [..._songs]..removeAt(i);
    _songs = List.unmodifiable(updated);

    if (wasCurrent) {
      _index = -1;
    } else if (i < _index) {
      _index--; // a song before the current one disappeared
    }
    return wasCurrent;
  }
}
