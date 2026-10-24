import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/models/song.dart';
import 'package:loop_player/domain/library/song_search.dart';

Song _song(String id, String title, {String? artist, String? album}) => Song(
      id: id,
      title: title,
      artist: artist,
      album: album,
      durationMs: 1000,
      filePath: 'music/$id.mp3',
      importedAt: 0,
    );

void main() {
  final songs = [
    _song('1', 'Blinding Lights', artist: 'The Weeknd', album: 'After Hours'),
    _song('2', 'Heat Waves', artist: 'Glass Animals', album: 'Dreamland'),
    _song('3', 'Untitled'),
  ];

  test('empty or blank query returns every song', () {
    expect(filterSongs(songs, ''), songs);
    expect(filterSongs(songs, '   '), songs);
  });

  test('matches title, ignoring case', () {
    expect(filterSongs(songs, 'blinding').map((s) => s.id), ['1']);
  });

  test('matches artist', () {
    expect(filterSongs(songs, 'glass').map((s) => s.id), ['2']);
  });

  test('matches album', () {
    expect(filterSongs(songs, 'DREAMLAND').map((s) => s.id), ['2']);
  });

  test('trims the query and handles songs with no artist or album', () {
    expect(filterSongs(songs, '  untitled ').map((s) => s.id), ['3']);
  });

  test('returns nothing when nothing matches', () {
    expect(filterSongs(songs, 'zzz'), isEmpty);
  });
}
