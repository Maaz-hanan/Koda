import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/models/playlist.dart';
import 'package:loop_player/data/models/song.dart';
import 'package:loop_player/domain/library/playlist_rules.dart';

Song _song(String id, {bool fav = false}) => Song(
      id: id,
      title: 'Song $id',
      durationMs: 1000,
      filePath: 'music/$id.mp3',
      importedAt: 0,
      isFavorite: fav,
    );

Playlist _pl(String id, String name) =>
    Playlist(id: id, name: name, createdAt: 0);

void main() {
  group('validatePlaylistName', () {
    test('a normal name is fine', () {
      expect(validatePlaylistName('Gym', const []), isNull);
      expect(validatePlaylistName('  Road trip  ', ['Gym']), isNull);
    });

    test('empty or blank is rejected', () {
      expect(validatePlaylistName('', const []), isNotNull);
      expect(validatePlaylistName('    ', const []), isNotNull);
    });

    test('too long is rejected, the limit itself is fine', () {
      expect(validatePlaylistName('a' * maxPlaylistNameLength, const []),
          isNull);
      expect(validatePlaylistName('a' * (maxPlaylistNameLength + 1), const []),
          isNotNull);
    });

    test('a duplicate is rejected ignoring case and spaces', () {
      expect(validatePlaylistName('gym', ['Gym']), isNotNull);
      expect(validatePlaylistName('  GYM ', ['Gym']), isNotNull);
    });
  });

  group('songsForIds', () {
    final all = [_song('a'), _song('b'), _song('c')];

    test('keeps the playlist order, not the library order', () {
      expect(songsForIds(['c', 'a'], all).map((s) => s.id), ['c', 'a']);
    });

    test('skips ids with no song', () {
      expect(songsForIds(['a', 'zzz', 'b'], all).map((s) => s.id), ['a', 'b']);
    });

    test('uses the live song (fresh heart)', () {
      final live = [_song('a', fav: true)];
      expect(songsForIds(['a'], live).single.isFavorite, isTrue);
    });

    test('empty playlist gives no songs', () {
      expect(songsForIds([], all), isEmpty);
    });
  });

  group('filterPlaylists', () {
    final lists = [_pl('1', 'Gym'), _pl('2', 'Road trip')];

    test('empty query keeps everything', () {
      expect(filterPlaylists(lists, ' '), lists);
    });

    test('matches part of the name, ignoring case', () {
      expect(filterPlaylists(lists, 'ROAD').map((p) => p.id), ['2']);
      expect(filterPlaylists(lists, 'zzz'), isEmpty);
    });
  });

  test('songCountText', () {
    expect(songCountText(0), '0 songs');
    expect(songCountText(1), '1 song');
    expect(songCountText(2), '2 songs');
  });

  group('PlaylistLibrary', () {
    final lib = PlaylistLibrary(
      playlists: [_pl('1', 'Gym')],
      songIds: const {'1': ['a', 'b']},
    );

    test('ids, count and lookup', () {
      expect(lib.idsOf('1'), ['a', 'b']);
      expect(lib.countOf('1'), 2);
      expect(lib.byId('1')?.name, 'Gym');
    });

    test('unknown playlist is empty / null', () {
      expect(lib.idsOf('x'), isEmpty);
      expect(lib.countOf('x'), 0);
      expect(lib.byId('x'), isNull);
      expect(const PlaylistLibrary.empty().playlists, isEmpty);
    });

    test('Playlist survives a map round trip', () {
      final back = Playlist.fromMap(_pl('1', 'Gym').toMap());
      expect(back.id, '1');
      expect(back.name, 'Gym');
    });
  });
}
