import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the single SQLite database used by the whole app.
///
/// Think of this as "opening the filing cabinet". Everything else
/// (SongDao, LoopProfileDao) just asks this class for the open cabinet.
class AppDatabase {
  AppDatabase._();

  /// The one and only instance (a "singleton").
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'loop_player.db';

  /// Bump this number whenever you change the table structure,
  /// and add a migration in [_onUpgrade].
  static const _dbVersion = 1;

  Future<Database>? _opening;

  /// Opens the database the first time it is asked for, then reuses it.
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      // Foreign keys are OFF by default in SQLite. We need them ON so that
      // deleting a song automatically deletes its loop profile.
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Nothing to migrate yet (we are on version 1).
  }
}
