import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/models/song.dart';
import 'package:loop_player/domain/playback/playback_restore.dart';

Song _song(String id) => Song(
      id: id,
      title: 'Song $id',
      durationMs: 60000,
      filePath: 'music/$id.mp3',
      importedAt: 0,
    );

void main() {
  group('SavedPlayback', () {
    test('round-trips through JSON text', () {
      const saved = SavedPlayback(
        queueIds: ['a', 'b', 'c'],
        currentId: 'b',
        positionMs: 12345,
      );
      final back = SavedPlayback.tryParse(saved.toJsonString())!;
      expect(back.queueIds, ['a', 'b', 'c']);
      expect(back.currentId, 'b');
      expect(back.positionMs, 12345);
    });

    test('returns null for missing or damaged data', () {
      expect(SavedPlayback.tryParse(null), isNull);
      expect(SavedPlayback.tryParse(''), isNull);
      expect(SavedPlayback.tryParse('not json'), isNull);
      expect(SavedPlayback.tryParse('[1,2]'), isNull);
      expect(SavedPlayback.tryParse('{"queue":[1],"current":"a","positionMs":0}'),
          isNull);
      expect(SavedPlayback.tryParse('{"queue":["a"],"current":"a"}'), isNull);
    });

    test('negative position becomes 0', () {
      final s = SavedPlayback.tryParse(
          '{"queue":["a"],"current":"a","positionMs":-5}')!;
      expect(s.positionMs, 0);
    });
  });

  group('resolveRestore', () {
    final library = [_song('a'), _song('b'), _song('c')];

    test('rebuilds queue, index and position', () {
      const saved = SavedPlayback(
          queueIds: ['a', 'b', 'c'], currentId: 'b', positionMs: 5000);
      final r = resolveRestore(saved, library)!;
      expect(r.songs.map((s) => s.id), ['a', 'b', 'c']);
      expect(r.startIndex, 1);
      expect(r.positionMs, 5000);
    });

    test('drops removed songs and fixes the index', () {
      const saved = SavedPlayback(
          queueIds: ['x', 'a', 'c'], currentId: 'c', positionMs: 0);
      final r = resolveRestore(saved, library)!;
      expect(r.songs.map((s) => s.id), ['a', 'c']);
      expect(r.startIndex, 1);
    });

    test('returns null when the current song was removed', () {
      const saved = SavedPlayback(
          queueIds: ['a', 'x'], currentId: 'x', positionMs: 0);
      expect(resolveRestore(saved, library), isNull);
    });

    test('returns null for an empty library', () {
      const saved =
          SavedPlayback(queueIds: ['a'], currentId: 'a', positionMs: 0);
      expect(resolveRestore(saved, const []), isNull);
    });
  });
}
