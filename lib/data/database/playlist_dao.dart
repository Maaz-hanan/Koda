import 'package:sqflite/sqflite.dart';

import '../models/playlist.dart';
import 'app_database.dart';

/// The only place that writes SQL for playlists.
class PlaylistDao {
  PlaylistDao(this._appDb);

  final AppDatabase _appDb;

  static const _playlists = 'playlists';
  static const _links = 'playlist_songs';

  Future<List<Playlist>> getAll() async {
    final db = await _appDb.database;
    final rows = await db.query(_playlists, orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Playlist.fromMap).toList();
  }

  /// playlist id -> its song ids in play order (one query for all playlists).
  Future<Map<String, List<String>>> getAllSongIds() async {
    final db = await _appDb.database;
    final rows = await db.query(
      _links,
      columns: ['playlist_id', 'song_id'],
      orderBy: 'playlist_id ASC, position ASC, added_at ASC',
    );
    final result = <String, List<String>>{};
    for (final r in rows) {
      (result[r['playlist_id'] as String] ??= <String>[])
          .add(r['song_id'] as String);
    }
    return result;
  }

  Future<void> insert(Playlist playlist) async {
    final db = await _appDb.database;
    await db.insert(_playlists, playlist.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> rename(String id, String name) async {
    final db = await _appDb.database;
    await db.update(_playlists, {'name': name},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes the playlist; its links go too (ON DELETE CASCADE).
  /// The songs themselves are NOT touched.
  Future<void> delete(String id) async {
    final db = await _appDb.database;
    await db.delete(_playlists, where: 'id = ?', whereArgs: [id]);
  }

  /// Adds a song at the END of the playlist. Returns false (and changes
  /// nothing) if it is already in it.
  Future<bool> addSong(String playlistId, String songId, int nowMs) async {
    final db = await _appDb.database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        _links,
        columns: ['song_id'],
        where: 'playlist_id = ? AND song_id = ?',
        whereArgs: [playlistId, songId],
        limit: 1,
      );
      if (existing.isNotEmpty) return false;

      final next = await txn.rawQuery(
        'SELECT COALESCE(MAX(position), -1) + 1 AS next '
        'FROM $_links WHERE playlist_id = ?',
        [playlistId],
      );
      await txn.insert(_links, {
        'playlist_id': playlistId,
        'song_id': songId,
        'position': next.first['next'] as int,
        'added_at': nowMs,
      });
      return true;
    });
  }

  /// Saves a new order: the song at index i gets position i. All or nothing.
  /// Only touches songs that are in the playlist.
  Future<void> setOrder(String playlistId, List<String> orderedSongIds) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedSongIds.length; i++) {
        await txn.update(
          _links,
          {'position': i},
          where: 'playlist_id = ? AND song_id = ?',
          whereArgs: [playlistId, orderedSongIds[i]],
        );
      }
    });
  }

  Future<void> removeSong(String playlistId, String songId) async {
    final db = await _appDb.database;
    await db.delete(_links,
        where: 'playlist_id = ? AND song_id = ?',
        whereArgs: [playlistId, songId]);
  }
}
