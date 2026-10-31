import 'dart:math' as math;

import '../../data/models/song.dart';

/// What happened when a song was added to the queue ("Play next" /
/// "Add to queue"). [PRD FR-008]
enum QueueAddResult {
  /// The song was put into the queue.
  added,

  /// The song was already queued and was moved to the new place.
  moved,

  /// Nothing changed (already in the queue / already next).
  unchanged,

  /// It is the song playing right now; nothing changed.
  isCurrent,

  /// The queue was empty, so the song simply started playing.
  /// (Decided by the audio handler, never returned by [QueueManager].)
  started,
}

/// The text shown after "Play next" / "Add to queue". Pure so it is tested.
String queueAddMessage(
  QueueAddResult result, {
  required bool playNext,
  required String title,
}) {
  switch (result) {
    case QueueAddResult.started:
      return 'Playing "$title".';
    case QueueAddResult.isCurrent:
      return 'That song is playing now.';
    case QueueAddResult.unchanged:
      return playNext ? 'Already playing next.' : 'Already in the queue.';
    case QueueAddResult.added:
    case QueueAddResult.moved:
      return playNext ? 'Will play next.' : 'Added to the queue.';
  }
}

/// Pure bookkeeping for "which songs are queued and which one is current".
/// No audio in here, so it can be unit-tested. [PRD FR-008]
///
/// Rules (predictable, per the PRD):
///  * Next on the last song does NOT wrap around (moveToNext returns false).
///  * Previous on the first song does not move (moveToPrevious returns false).
class QueueManager {
  List<Song> _songs = const [];
  int _index = -1;

  /// The queue as it was before shuffling (null = not shuffled), so that
  /// turning shuffle off can put the songs back in their old order.
  List<Song>? _unshuffled;

  List<Song> get songs => _songs;

  /// Index of the current song, or -1 if nothing is current.
  int get index => _index;

  Song? get current =>
      (_index >= 0 && _index < _songs.length) ? _songs[_index] : null;

  bool get hasNext => _index >= 0 && _index < _songs.length - 1;
  bool get hasPrevious => _index > 0;

  void setQueue(List<Song> songs, int startIndex) {
    _unshuffled = null; // a brand-new queue starts in its own order
    _songs = List.unmodifiable(songs);
    if (songs.isEmpty) {
      _index = -1;
    } else {
      _index = startIndex.clamp(0, songs.length - 1).toInt();
    }
  }

  /// True while the queue is in shuffled order. [PRD FR-008]
  bool get isShuffled => _unshuffled != null;

  /// Shuffle: mixes the songs AFTER the current one. The songs before it
  /// (already played) and the current song stay where they are. The first
  /// original order is remembered, so shuffling twice still restores the
  /// real original order.
  void shuffleUpcoming(math.Random random) {
    _unshuffled ??= List.of(_songs);
    final head = _songs.take(_index + 1).toList();
    final tail = _songs.skip(_index + 1).toList()..shuffle(random);
    _songs = List.unmodifiable([...head, ...tail]);
  }

  /// "Shuffle" on a whole list: all of [songs] in random order, starting at
  /// the first one. The given order is remembered for [restoreOrder].
  void setShuffledQueue(List<Song> songs, math.Random random) {
    if (songs.isEmpty) {
      setQueue(songs, 0);
      return;
    }
    _songs = List.unmodifiable(List.of(songs)..shuffle(random));
    _index = 0;
    _unshuffled = List.of(songs);
  }

  /// Shuffle off: puts the songs back in their original order and keeps the
  /// current song playing. Songs removed while shuffled stay removed; songs
  /// added while shuffled (Play next / Add to queue) go to the end.
  void restoreOrder() {
    final original = _unshuffled;
    if (original == null) return;
    final currentId = current?.id;
    final inQueue = {for (final s in _songs) s.id: s};

    final restored = <Song>[
      for (final s in original)
        if (inQueue.containsKey(s.id)) inQueue[s.id]!,
    ];
    final restoredIds = {for (final s in restored) s.id};
    restored.addAll(_songs.where((s) => !restoredIds.contains(s.id)));

    _songs = List.unmodifiable(restored);
    _index = currentId == null
        ? -1
        : restored.indexWhere((s) => s.id == currentId);
    _unshuffled = null;
  }

  bool moveToNext() {
    if (!hasNext) return false;
    _index++;
    return true;
  }

  /// Makes the song at [index] the current one (tap in the queue view).
  /// Returns false, changing nothing, if [index] is outside the queue.
  bool moveTo(int index) {
    if (index < 0 || index >= _songs.length) return false;
    _index = index;
    return true;
  }

  /// "Play next": puts [song] right after the current song. A song can be in
  /// the queue only ONCE, so a queued song is moved instead of duplicated.
  QueueAddResult playNext(Song song) {
    if (current?.id == song.id) return QueueAddResult.isCurrent;

    final list = [..._songs];
    final existing = list.indexWhere((s) => s.id == song.id);
    if (existing >= 0) {
      if (existing == _index + 1) return QueueAddResult.unchanged;
      list.removeAt(existing);
      if (existing < _index) _index--; // a song before the current one left
    }
    list.insert(_index + 1, song);
    _songs = List.unmodifiable(list);
    return existing >= 0 ? QueueAddResult.moved : QueueAddResult.added;
  }

  /// "Add to queue": puts [song] at the end. Already queued -> unchanged.
  QueueAddResult addToEnd(Song song) {
    if (current?.id == song.id) return QueueAddResult.isCurrent;
    if (_songs.any((s) => s.id == song.id)) return QueueAddResult.unchanged;
    _songs = List.unmodifiable([..._songs, song]);
    return QueueAddResult.added;
  }

  bool moveToPrevious() {
    if (!hasPrevious) return false;
    _index--;
    return true;
  }

  /// Nothing is current any more (e.g. playback stopped).
  void clearCurrent() => _index = -1;

  /// Swaps in the edited copy of a song (new title or cover) everywhere it
  /// is queued. The order and the current position do not change.
  void replaceSong(Song updated) {
    List<Song> swap(List<Song> list) => List.unmodifiable([
          for (final s in list) s.id == updated.id ? updated : s,
        ]);
    _songs = swap(_songs);
    final original = _unshuffled;
    if (original != null) _unshuffled = swap(original);
  }

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
