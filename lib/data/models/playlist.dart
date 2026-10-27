import 'package:flutter/foundation.dart';

/// A named list of songs the user made. [PRD FR-003]
/// The songs themselves are in [PlaylistLibrary.songIds].
@immutable
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  /// UUID v4 primary key.
  final String id;
  final String name;

  /// Unix epoch timestamp (ms).
  final int createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt,
      };

  factory Playlist.fromMap(Map<String, dynamic> map) => Playlist(
        id: map['id'] as String,
        name: map['name'] as String,
        createdAt: map['created_at'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Playlist && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Every playlist plus the ordered song ids of each, loaded together so the
/// screens never show a half-loaded playlist.
@immutable
class PlaylistLibrary {
  const PlaylistLibrary({required this.playlists, required this.songIds});

  const PlaylistLibrary.empty()
      : playlists = const [],
        songIds = const {};

  /// Sorted by name, ignoring case.
  final List<Playlist> playlists;

  /// playlist id -> song ids in play order.
  final Map<String, List<String>> songIds;

  List<String> idsOf(String playlistId) => songIds[playlistId] ?? const [];

  int countOf(String playlistId) => idsOf(playlistId).length;

  Playlist? byId(String playlistId) {
    for (final p in playlists) {
      if (p.id == playlistId) return p;
    }
    return null;
  }
}
