import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/core/song_title.dart';
import 'package:loop_player/data/models/song.dart';
import 'package:loop_player/domain/playback/queue_manager.dart';

Song _song(String id, String title) => Song(
      id: id,
      title: title,
      durationMs: 1000,
      filePath: 'music/$id.mp3',
      importedAt: 0,
    );

void main() {
  group('cleanSongTitle', () {
    test('trims and collapses spaces', () {
      expect(cleanSongTitle('  My   new \n song  '), 'My new song');
    });

    test('empty or blank gives null', () {
      expect(cleanSongTitle(''), isNull);
      expect(cleanSongTitle('   \n\t '), isNull);
    });

    test('is cut at the maximum length', () {
      final long = 'a' * (kMaxSongTitleLength + 50);
      expect(cleanSongTitle(long)!.length, kMaxSongTitleLength);
    });
  });

  group('QueueManager.replaceSong', () {
    test('swaps the song, keeps order and position', () {
      final q = QueueManager()
        ..setQueue([_song('a', 'A'), _song('b', 'B'), _song('c', 'C')], 1);
      q.replaceSong(_song('b', 'B renamed'));

      expect(q.songs.map((s) => s.title), ['A', 'B renamed', 'C']);
      expect(q.index, 1);
      expect(q.current!.title, 'B renamed');
    });

    test('an unknown song changes nothing', () {
      final q = QueueManager()..setQueue([_song('a', 'A')], 0);
      q.replaceSong(_song('zzz', 'Other'));
      expect(q.songs.map((s) => s.title), ['A']);
    });
  });
}
