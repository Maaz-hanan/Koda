import '../../data/models/playlist.dart';
import '../../data/models/song.dart';

const int maxPlaylistNameLength = 60;

/// Returns a message for the user if [raw] is not an acceptable playlist
/// name, or null if it is fine. [existingNames] are the OTHER playlists'
/// names (when renaming, leave the playlist's own current name out so
/// "gym" -> "Gym" is allowed). Duplicates are compared ignoring case.
String? validatePlaylistName(String raw, Iterable<String> existingNames) {
  final name = raw.trim();
  if (name.isEmpty) return 'Enter a name.';
  if (name.length > maxPlaylistNameLength) {
    return 'Use $maxPlaylistNameLength characters or fewer.';
  }
  final lower = name.toLowerCase();
  if (existingNames.any((n) => n.trim().toLowerCase() == lower)) {
    return 'You already have a playlist with that name.';
  }
  return null;
}

/// The playlist's songs in playlist order. Ids with no matching song (should
/// not happen: removing a song also removes its playlist entries) are skipped.
/// Built from the live song list so hearts stay up to date.
List<Song> songsForIds(List<String> ids, List<Song> all) {
  final byId = {for (final s in all) s.id: s};
  return [
    for (final id in ids)
      if (byId[id] != null) byId[id]!,
  ];
}

/// Search box on the Playlists tab: name contains the query, ignoring case.
List<Playlist> filterPlaylists(List<Playlist> playlists, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return playlists;
  return playlists.where((p) => p.name.toLowerCase().contains(q)).toList();
}

/// Returns a copy of [items] with the item at [oldIndex] moved so that it
/// ends up AT [newIndex] of the result. This is exactly what Flutter's
/// `ReorderableListView.onReorderItem` reports (the index is already
/// corrected for the removed item). Out-of-range indexes are clamped.
/// [PRD FR-003]
List<T> moveItem<T>(List<T> items, int oldIndex, int newIndex) {
  if (oldIndex < 0 || oldIndex >= items.length) return [...items];
  final list = [...items];
  final item = list.removeAt(oldIndex);
  list.insert(newIndex.clamp(0, list.length).toInt(), item);
  return list;
}

String songCountText(int count) => count == 1 ? '1 song' : '$count songs';
