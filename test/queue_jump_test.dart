import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/models/song.dart';
import 'package:loop_player/domain/playback/queue_manager.dart';
import 'package:loop_player/domain/playback/queue_position.dart';

Song _song(String id) => Song(
      id: id,
      title: 'Song $id',
      durationMs: 1000,
      filePath: 'music/$id.mp3',
      importedAt: 0,
    );

void main() {
  late QueueManager q;
  final a = _song('a'), b = _song('b'), c = _song('c'), d = _song('d');

  setUp(() {
    q = QueueManager()..setQueue([a, b, c, d], 1);
  });

  group('QueueManager.moveTo', () {
    test('jumps forward and backward', () {
      expect(q.moveTo(3), isTrue);
      expect(q.current, d);
      expect(q.moveTo(0), isTrue);
      expect(q.current, a);
    });

    test('an index outside the queue changes nothing', () {
      expect(q.moveTo(-1), isFalse);
      expect(q.moveTo(4), isFalse);
      expect(q.current, b);
      expect(q.index, 1);
    });

    test('Next and Previous continue from the jumped-to song', () {
      q.moveTo(2);
      expect(q.moveToNext(), isTrue);
      expect(q.current, d);
      q.moveTo(2);
      expect(q.moveToPrevious(), isTrue);
      expect(q.current, b);
    });

    test('an empty queue cannot be jumped in', () {
      q.setQueue([], 0);
      expect(q.moveTo(0), isFalse);
    });

    test('removing a song then jumping uses the new positions', () {
      q.remove('a'); // queue is now b, c, d and b is still current
      expect(q.index, 0);
      expect(q.moveTo(2), isTrue);
      expect(q.current, d);
    });
  });

  group('indexOfSong', () {
    test('finds the playing song', () {
      expect(indexOfSong(['a', 'b', 'c'], 'c'), 2);
      expect(indexOfSong(['a', 'b', 'c'], 'a'), 0);
    });

    test('nothing playing or not in the queue gives -1', () {
      expect(indexOfSong(['a', 'b'], null), -1);
      expect(indexOfSong(['a', 'b'], 'z'), -1);
      expect(indexOfSong([], 'a'), -1);
    });
  });
}
