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

void main() {
  late QueueManager q;
  final a = _song('a'), b = _song('b'), c = _song('c');

  setUp(() {
    q = QueueManager()..setQueue([a, b, c], 1);
  });

  test('starts at the requested song', () {
    expect(q.current, b);
    expect(q.index, 1);
    expect(q.hasNext, isTrue);
    expect(q.hasPrevious, isTrue);
  });

  test('empty queue has no current song', () {
    q.setQueue([], 0);
    expect(q.current, isNull);
    expect(q.index, -1);
    expect(q.hasNext, isFalse);
  });

  test('out-of-range start index is clamped', () {
    q.setQueue([a, b], 99);
    expect(q.current, b);
  });

  test('moveToNext advances, and stops at the end without wrapping', () {
    expect(q.moveToNext(), isTrue);
    expect(q.current, c);
    expect(q.moveToNext(), isFalse);
    expect(q.current, c);
  });

  test('moveToPrevious goes back, and stops at the start', () {
    expect(q.moveToPrevious(), isTrue);
    expect(q.current, a);
    expect(q.moveToPrevious(), isFalse);
    expect(q.current, a);
  });

  test('removing the current song reports it and leaves nothing current', () {
    expect(q.remove('b'), isTrue);
    expect(q.current, isNull);
    expect(q.songs, [a, c]);
  });

  test('removing an earlier song keeps the same song current', () {
    expect(q.remove('a'), isFalse);
    expect(q.current, b);
    expect(q.index, 0);
  });

  test('removing a later song does not change the current song', () {
    expect(q.remove('c'), isFalse);
    expect(q.current, b);
    expect(q.index, 1);
  });

  test('removing an unknown song changes nothing', () {
    expect(q.remove('zzz'), isFalse);
    expect(q.songs.length, 3);
    expect(q.current, b);
  });

  test('clearCurrent leaves the list but no current song', () {
    q.clearCurrent();
    expect(q.current, isNull);
    expect(q.songs.length, 3);
  });
}
