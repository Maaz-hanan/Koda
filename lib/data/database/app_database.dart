import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the single SQLite database used by the whole app.
///
/// Think of this as "opening the filing cabinet". Everything else
/// (SongDao, LoopProfileDao, PlaylistDao) just asks this class for the open
/// cabinet.
class AppDatabase {
  AppDatabase._([this._pathOverride]);

  /// A database in a file of the test's choosing (never the real library).
  @visibleForTesting
  factory AppDatabase.forTesting(String path) => AppDatabase._(path);

  /// The one and only instance (a "singleton").
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'loop_player.db';

  final String? _pathOverride;

  /// Bump this number whenever you change the table structure,
  /// and add a migration in [_onUpgrade].
  ///
  /// Version history:
  ///  1 = songs + loop_profiles.
  ///  2 = adds playlists + playlist_songs (ONLY new tables; songs and
  ///      loop_profiles are not touched, so nothing can be lost).
  static const _dbVersion = 2;

  Future<Database>? _opening;

  /// Opens the database the first time it is asked for, then reuses it.
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final path = _pathOverride ?? p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      // Foreign keys are OFF by default in SQLite. We need them ON so that
      // deleting a song automatically deletes its loop profile and its
      // playlist entries.
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE songs (
        id             TEXT PRIMARY KEY,
        title          TEXT NOT NULL,
        artist         TEXT,
        album          TEXT,
        duration_ms    INTEGER NOT NULL DEFAULT 0,
        artwork_path   TEXT,
        file_path      TEXT NOT NULL,
        imported_at    INTEGER NOT NULL,
        last_played_at INTEGER,
        is_favorite    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // One saved loop profile per song. PRD FR-018 / FR-019.
    await db.execute('''
      CREATE TABLE loop_profiles (
        song_id              TEXT PRIMARY KEY
                             REFERENCES songs(id) ON DELETE CASCADE,
        mode                 TEXT NOT NULL,
        loop_start_ms        INTEGER,
        loop_end_ms          INTEGER,
        finite_count         INTEGER,
        auto_loop_prefs_json TEXT,
        updated_at           INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_songs_title ON songs(title COLLATE NOCASE)');

    await _createPlaylistTables(db);
  }

  /// Runs once, when an existing database is older than [_dbVersion].
  /// sqflite wraps it in a transaction: if anything fails, nothing changes.
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPlaylistTables(db);
    }
  }

  /// Version 2. Used by BOTH a fresh install ([_onCreate]) and an upgrade
  /// ([_onUpgrade]) so the two always end up identical. [PRD FR-003]
  static Future<void> _createPlaylistTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS playlists (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // A song can be in a playlist only once (the primary key). Deleting a
    // playlist or a song removes the link automatically (ON DELETE CASCADE).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS playlist_songs (
        playlist_id TEXT NOT NULL
                    REFERENCES playlists(id) ON DELETE CASCADE,
        song_id     TEXT NOT NULL
                    REFERENCES songs(id) ON DELETE CASCADE,
        position    INTEGER NOT NULL,
        added_at    INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, song_id)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_playlist_songs_order
      ON playlist_songs(playlist_id, position)
    ''');
  }
}
