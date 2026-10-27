import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/models/song.dart';
import 'package:loop_player/domain/library/library_views.dart';

Song _song(
  String id,
  String title, {
  bool fav = false,
  int? played,
}) =>
    Song(
      id: id,
      title: title,
      durationMs: 1000,
      filePath: 'music/$id.mp3',
      importedAt: 0,
      isFavorite: fav,
      lastPlayedAt: played,
    );

void main() {
  group('favoriteSongs', () {
    test('only favorites, sorted by title', () {
      final result = favoriteSongs([
        _song('1', 'Zebra', fav: true),
        _song('2', 'Mango'),
        _song('3', 'apple', fav: true),
      ]);
      expect(result.map((s) => s.id), ['3', '1']);
    });

    test('none hearted -> empty', () {
      expect(favoriteSongs([_song('1', 'a')]), isEmpty);
    });
  });

  group('recentlyPlayedSongs', () {
    test('newest first and never-played songs are left out', () {
      final result = recentlyPlayedSongs([
        _song('1', 'a', played: 100),
        _song('2', 'b'),
        _song('3', 'c', played: 300),
        _song('4', 'd', played: 200),
      ]);
      expect(result.map((s) => s.id), ['3', '4', '1']);
    });

    test('same time -> by title', () {
      final result = recentlyPlayedSongs([
        _song('1', 'b', played: 5),
        _song('2', 'a', played: 5),
      ]);
      expect(result.map((s) => s.id), ['2', '1']);
    });

    test('keeps at most the limit', () {
      final songs = [
        for (var i = 0; i < 5; i++) _song('$i', 't$i', played: i),
      ];
      expect(recentlyPlayedSongs(songs, limit: 3).map((s) => s.id),
          ['4', '3', '2']);
      expect(recentlyPlayedSongs(songs).length, 5);
    });
  });
}
