import 'package:sqflite/sqflite.dart';

import '../models/song.dart';
import 'app_database.dart';

/// DAO = "Data Access Object". The only place that writes SQL for songs.
class SongDao {
  SongDao(this._appDb);

  final AppDatabase _appDb;

  static const _table = 'songs';

  Future<void> insert(Song song) async {
    final db = await _appDb.database;
    await db.insert(_table, song.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<List<Song>> getAll() async {
    final db = await _appDb.database;
    final rows = await db.query(_table, orderBy: 'title COLLATE NOCASE ASC');
    return rows.map(Song.fromMap).toList();
  }

  Future<Song?> getById(String id) async {
    final db = await _appDb.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Song.fromMap(rows.first);
  }

  Future<void> update(Song song) async {
    final db = await _appDb.database;
    await db.update(_table, song.toMap(), where: 'id = ?', whereArgs: [song.id]);
  }

  Future<void> delete(String id) async {
    final db = await _appDb.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
