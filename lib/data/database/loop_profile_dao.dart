import 'package:sqflite/sqflite.dart';

import '../models/loop_profile.dart';
import 'app_database.dart';

class LoopProfileDao {
  LoopProfileDao(this._appDb);

  final AppDatabase _appDb;

  static const _table = 'loop_profiles';

  /// Insert or replace the profile for a song (one row per song).
  Future<void> upsert(LoopProfile profile) async {
    final db = await _appDb.database;
    await db.insert(_table, profile.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<LoopProfile?> getBySongId(String songId) async {
    final db = await _appDb.database;
    final rows = await db.query(_table, where: 'song_id = ?', whereArgs: [songId], limit: 1);
    return rows.isEmpty ? null : LoopProfile.fromMap(rows.first);
  }

  Future<void> delete(String songId) async {
    final db = await _appDb.database;
    await db.delete(_table, where: 'song_id = ?', whereArgs: [songId]);
  }
}
