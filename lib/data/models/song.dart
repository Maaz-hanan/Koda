import 'package:flutter/foundation.dart';

/// Immutable representation of a song stored in the local library.
///
/// All file-path fields point to app-managed storage (copied on import).
/// [PRD FR-002]
@immutable
class Song {
  const Song({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    required this.durationMs,
    this.artworkPath,
    required this.filePath,
    required this.importedAt,
    this.lastPlayedAt,
    this.isFavorite = false,
  });

  /// UUID v4 primary key.
  final String id;

  /// Display title. Never null — falls back to the filename if metadata has none.
  final String title;

  final String? artist;
  final String? album;

  /// Track duration in milliseconds. 0 if metadata did not contain a duration.
  final int durationMs;

  /// Path of the artwork file RELATIVE to the app Documents folder
  /// (e.g. "artwork/<id>.jpg"), or null. Use `song.absoluteArtworkPath`.
  final String? artworkPath;

  /// Path of the audio file RELATIVE to the app Documents folder
  /// (e.g. "music/<id>.mp3"). Use `song.absoluteFilePath` to read it.
  final String filePath;

  /// Unix epoch timestamp (ms) when the file was imported.
  final int importedAt;

  /// Unix epoch timestamp (ms) of the most recent play, or null if never played.
  final int? lastPlayedAt;

  final bool isFavorite;

  // ---------------------------------------------------------------------------
  // Convenience accessors
  // ---------------------------------------------------------------------------

  Duration get duration => Duration(milliseconds: durationMs);

  /// Never-null artist string for display purposes.
  String get displayArtist => artist ?? 'Unknown Artist';

  /// Never-null album string for display purposes.
  String get displayAlbum => album ?? 'Unknown Album';

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'duration_ms': durationMs,
        'artwork_path': artworkPath,
        'file_path': filePath,
        'imported_at': importedAt,
        'last_played_at': lastPlayedAt,
        'is_favorite': isFavorite ? 1 : 0,
      };

  factory Song.fromMap(Map<String, dynamic> map) => Song(
        id: map['id'] as String,
        title: map['title'] as String,
        artist: map['artist'] as String?,
        album: map['album'] as String?,
        durationMs: map['duration_ms'] as int? ?? 0,
        artworkPath: map['artwork_path'] as String?,
        filePath: map['file_path'] as String,
        importedAt: map['imported_at'] as int,
        lastPlayedAt: map['last_played_at'] as int?,
        isFavorite: ((map['is_favorite'] as int?) ?? 0) == 1,
      );

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    String? artworkPath,
    String? filePath,
    int? importedAt,
    int? lastPlayedAt,
    bool? isFavorite,
  }) =>
      Song(
        id: id ?? this.id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        durationMs: durationMs ?? this.durationMs,
        artworkPath: artworkPath ?? this.artworkPath,
        filePath: filePath ?? this.filePath,
        importedAt: importedAt ?? this.importedAt,
        lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Song && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
