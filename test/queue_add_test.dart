import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/models/song.dart';
import 'package:loop_player/domain/playback/queue_manager.dart';

Song _song(String id) => Song(
      id: id,
      title: 'Song $id',
      durationMs: 1000,
      filePath: 'music/$id.mp3',
      importedAt: 0,
    );

List<String> _ids(QueueManager q) => q.songs.map((s) => s.id).toList();

void main() {
  final a = _song('a'), b = _song('b'), c = _song('c'), d = _song('d');
  final e = _song('e');
  late QueueManager q;

  setUp(() {
    q = QueueManager()..setQueue([a, b, c, d], 1); // b is playing
  });

  group('playNext', () {
    test('a new song goes right after the current one', () {
      expect(q.playNext(e), QueueAddResult.added);
      expect(_ids(q), ['a', 'b', 'e', 'c', 'd']);
      expect(q.current, b);
      expect(q.index, 1);
    });

    test('a queued song after the current one is MOVED, not duplicated', () {
      expect(q.playNext(d), QueueAddResult.moved);
      expect(_ids(q), ['a', 'b', 'd', 'c']);
      expect(q.current, b);
    });

    test('a queued song BEFORE the current one is moved and index follows', () {
      expect(q.playNext(a), QueueAddResult.moved);
      expect(_ids(q), ['b', 'a', 'c', 'd']);
      expect(q.current, b);
      expect(q.index, 0);
    });

    test('a song that is already next changes nothing', () {
      expect(q.playNext(c), QueueAddResult.unchanged);
      expect(_ids(q), ['a', 'b', 'c', 'd']);
    });

    test('the playing song changes nothing', () {
      expect(q.playNext(b), QueueAddResult.isCurrent);
      expect(_ids(q), ['a', 'b', 'c', 'd']);
    });

    test('Next then plays the added song', () {
      q.playNext(e);
      expect(q.moveToNext(), isTrue);
      expect(q.current, e);
    });

    test('with songs queued but none current, it goes to the front', () {
      q.clearCurrent();
      expect(q.playNext(e), QueueAddResult.added);
      expect(_ids(q), ['e', 'a', 'b', 'c', 'd']);
      expect(q.index, -1);
    });

    test('playing it twice in a row is harmless', () {
      q.playNext(e);
      expect(q.playNext(e), QueueAddResult.unchanged);
      expect(_ids(q), ['a', 'b', 'e', 'c', 'd']);
    });
  });

  group('addToEnd', () {
    test('a new song goes to the end', () {
      expect(q.addToEnd(e), QueueAddResult.added);
      expect(_ids(q), ['a', 'b', 'c', 'd', 'e']);
      expect(q.current, b);
    });

    test('an already queued song is left where it is', () {
      expect(q.addToEnd(a), QueueAddResult.unchanged);
      expect(_ids(q), ['a', 'b', 'c', 'd']);
    });

    test('the playing song changes nothing', () {
      expect(q.addToEnd(b), QueueAddResult.isCurrent);
      expect(_ids(q), ['a', 'b', 'c', 'd']);
    });

    test('works on the last song: Next now has somewhere to go', () {
      q.moveTo(3);
      expect(q.hasNext, isFalse);
      q.addToEnd(e);
      expect(q.hasNext, isTrue);
    });
  });

  group('queueAddMessage', () {
    String msg(QueueAddResult r, {required bool next}) =>
        queueAddMessage(r, playNext: next, title: 'Song');

    test('play next', () {
      expect(msg(QueueAddResult.added, next: true), 'Will play next.');
      expect(msg(QueueAddResult.moved, next: true), 'Will play next.');
      expect(msg(QueueAddResult.unchanged, next: true), 'Already playing next.');
    });

    test('add to queue', () {
      expect(msg(QueueAddResult.added, next: false), 'Added to the queue.');
      expect(msg(QueueAddResult.unchanged, next: false),
          'Already in the queue.');
    });

    test('both', () {
      expect(msg(QueueAddResult.started, next: true), 'Playing "Song".');
      expect(msg(QueueAddResult.started, next: false), 'Playing "Song".');
      expect(msg(QueueAddResult.isCurrent, next: true),
          'That song is playing now.');
    });
  });
}
