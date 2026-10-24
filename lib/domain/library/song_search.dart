import '../../data/models/song.dart';

/// Filters songs by title, artist or album. Case-insensitive; an empty
/// query returns everything. [PRD FR-004]
List<Song> filterSongs(List<Song> songs, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return songs;
  return songs
      .where((s) => [s.title, s.artist, s.album]
          .whereType<String>()
          .any((field) => field.toLowerCase().contains(q)))
      .toList();
}
