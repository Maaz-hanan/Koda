import '../../data/models/song.dart';

/// How many songs "Recently Played" shows at most.
const int recentlyPlayedLimit = 50;

int _byTitle(Song a, Song b) {
  final c = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// Only the hearted songs, sorted by title.
List<Song> favoriteSongs(List<Song> songs) =>
    songs.where((s) => s.isFavorite).toList()..sort(_byTitle);

/// Songs that have been played, newest first, at most [limit].
/// Never-played songs are left out.
List<Song> recentlyPlayedSongs(List<Song> songs,
    {int limit = recentlyPlayedLimit}) {
  final played = songs.where((s) => s.lastPlayedAt != null).toList()
    ..sort((a, b) {
      final c = b.lastPlayedAt!.compareTo(a.lastPlayedAt!);
      return c != 0 ? c : _byTitle(a, b);
    });
  return played.length > limit ? played.sublist(0, limit) : played;
}
