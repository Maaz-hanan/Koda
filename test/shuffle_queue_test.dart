import 'dart:math' as math;

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
  final all = [for (final id in 'abcdefgh'.split('')) _song(id)];
  late QueueManager q;

  setUp(() {
    q = QueueManager()..setQueue(all, 2); // c is playing
  });

  group('shuffleUpcoming', () {
    test('keeps the played songs and the current song, mixes only the rest',
        () {
      q.shuffleUpcoming(math.Random(7));

      expect(_ids(q).take(3), ['a', 'b', 'c']);
      expect(q.current?.id, 'c');
      expect(q.index, 2);
      expect(_ids(q).skip(3).toSet(), {'d', 'e', 'f', 'g', 'h'});
      expect(q.songs.length, 8);
      expect(q.isShuffled, isTrue);
    });

    test('never loses or duplicates a song', () {
      for (var seed = 0; seed < 30; seed++) {
        final m = QueueManager()..setQueue(all, 0);
        m.shuffleUpcoming(math.Random(seed));
        expect(_ids(m).toSet(), {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'});
        expect(m.songs.length, 8);
        expect(m.current?.id, 'a');
      }
    });

    test('shuffling again still remembers the REAL original order', () {
      q.shuffleUpcoming(math.Random(1));
      q.shuffleUpcoming(math.Random(2));
      q.restoreOrder();
      expect(_ids(q), ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']);
    });

    test('with nothing current, the whole queue is mixed', () {
      q.clearCurrent();
      q.shuffleUpcoming(math.Random(3));
      expect(_ids(q).toSet(), {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'});
      expect(q.current, isNull);
    });

    test('a one-song or empty queue is safe', () {
      final one = QueueManager()..setQueue([_song('x')], 0);
      one.shuffleUpcoming(math.Random(1));
      expect(_ids(one), ['x']);

      final none = QueueManager();
      none.shuffleUpcoming(math.Random(1));
      expect(none.songs, isEmpty);
    });
  });

  group('restoreOrder (shuffle off)', () {
    test('puts the original order back and keeps the same song playing', () {
      q.shuffleUpcoming(math.Random(7));
      q.moveToNext();
      q.moveToNext();
      final playing = q.current!.id;

      q.restoreOrder();

      expect(_ids(q), ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']);
      expect(q.current?.id, playing);
      expect(q.index, 'abcdefgh'.indexOf(playing));
      expect(q.isShuffled, isFalse);
    });

    test('songs removed while shuffled stay removed', () {
      q.shuffleUpcoming(math.Random(5));
      q.remove('e');
      q.restoreOrder();
      expect(_ids(q), ['a', 'b', 'c', 'd', 'f', 'g', 'h']);
    });

    test('songs added while shuffled go to the end', () {
      q.shuffleUpcoming(math.Random(5));
      q.addToEnd(_song('x'));
      q.playNext(_song('y'));
      q.restoreOrder();

      final ids = _ids(q);
      expect(ids.take(8), ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']);
      expect(ids.skip(8).toSet(), {'x', 'y'});
      expect(q.current?.id, 'c');
    });

    test('does nothing when the queue is not shuffled', () {
      q.restoreOrder();
      expect(_ids(q), ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']);
      expect(q.index, 2);
    });

    test('with nothing current, the index stays -1', () {
      q.clearCurrent();
      q.shuffleUpcoming(math.Random(2));
      q.restoreOrder();
      expect(_ids(q), ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']);
      expect(q.index, -1);
    });
  });

  group('setQueue and setShuffledQueue', () {
    test('a new queue is no longer shuffled', () {
      q.shuffleUpcoming(math.Random(1));
      q.setQueue(all, 0);
      expect(q.isShuffled, isFalse);
      expect(_ids(q), ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']);
    });

    test('the Shuffle button: every song, first one playing, restorable', () {
      q.setShuffledQueue(all, math.Random(11));

      expect(_ids(q).toSet(), {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'});
      expect(q.songs.length, 8);
      expect(q.index, 0);
      expect(q.isShuffled, isTrue);

      final playing = q.current!.id;
      q.restoreOrder();
      expect(_ids(q), ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']);
      expect(q.current?.id, playing);
    });

    test('shuffling an empty list gives an empty queue', () {
      q.setShuffledQueue(const [], math.Random(1));
      expect(q.songs, isEmpty);
      expect(q.index, -1);
    });
  });
}
