// Tests the REAL database code (migration + playlists) with real SQLite
// through sqflite_common_ffi. Everything happens in a temporary folder; the
// app's real library is never touched.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/database/app_database.dart';
import 'package:loop_player/data/database/playlist_dao.dart';
import 'package:loop_player/data/database/song_dao.dart';
import 'package:loop_player/data/models/song.dart';
import 'package:loop_player/data/repositories/playlist_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Song _song(String id) => Song(
      id: id,
      title: 'Song $id',
      durationMs: 1000,
      filePath: 'music/$id.mp3',
      importedAt: 1,
    );

/// The database exactly as version 1 of the app created it.
Future<void> _createVersion1(String path) async {
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
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
        await db.execute(
            'CREATE INDEX idx_songs_title ON songs(title COLLATE NOCASE)');
      },
    ),
  );
  await db.insert('songs', _song('old1').toMap()
    ..['is_favorite'] = 1
    ..['last_played_at'] = 777);
  await db.insert('songs', _song('old2').toMap());
  await db.insert('loop_profiles', {
    'song_id': 'old1',
    'mode': 'finiteSection',
    'loop_start_ms': 100,
    'loop_end_ms': 900,
    'finite_count': 3,
    'updated_at': 5,
  });
  await db.close();
}

Future<List<String>> _tables(Database db) async {
  final rows =
      await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
  return rows.map((r) => r['name'] as String).toList();
}

Future<int> _version(Database db) async {
  final rows = await db.rawQuery('PRAGMA user_version');
  return rows.first.values.first as int;
}

void main() {
  late Directory tmp;
  late String path;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('lp_db_test_');
    path = p.join(tmp.path, 'test.db');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  group('migration', () {
    test('a fresh install has all four tables at version 2', () async {
      final appDb = AppDatabase.forTesting(path);
      final db = await appDb.database;
      final tables = await _tables(db);
      expect(
          tables,
          containsAll(
              ['songs', 'loop_profiles', 'playlists', 'playlist_songs']));
      expect(await _version(db), 2);
      await db.close();
    });

    test('upgrading from version 1 keeps every song and loop', () async {
      await _createVersion1(path);

      final appDb = AppDatabase.forTesting(path);
      final db = await appDb.database;

      expect(await _version(db), 2);
      expect(await _tables(db), containsAll(['playlists', 'playlist_songs']));

      final songs = await SongDao(appDb).getAll();
      expect(songs.map((s) => s.id), unorderedEquals(['old1', 'old2']));
      final old1 = songs.firstWhere((s) => s.id == 'old1');
      expect(old1.isFavorite, isTrue);
      expect(old1.lastPlayedAt, 777);

      final loops = await db.query('loop_profiles');
      expect(loops.length, 1);
      expect(loops.first['finite_count'], 3);
      await db.close();
    });

    test('an upgraded database can use playlists straight away', () async {
      await _createVersion1(path);
      final appDb = AppDatabase.forTesting(path);
      final repo = PlaylistRepository(PlaylistDao(appDb));

      final pl = await repo.create('After upgrade');
      expect(await repo.addSong(pl.id, 'old1'), isTrue);

      final lib = await repo.getLibrary();
      expect(lib.idsOf(pl.id), ['old1']);
      await (await appDb.database).close();
    });

    test('opening an already-upgraded database again changes nothing',
        () async {
      await _createVersion1(path);
      final first = AppDatabase.forTesting(path);
      final repo = PlaylistRepository(PlaylistDao(first));
      final pl = await repo.create('Keep me');
      await repo.addSong(pl.id, 'old2');
      await (await first.database).close();

      final second = AppDatabase.forTesting(path);
      final lib = await PlaylistRepository(PlaylistDao(second)).getLibrary();
      expect(lib.playlists.map((x) => x.name), ['Keep me']);
      expect(lib.idsOf(pl.id), ['old2']);
      expect(await SongDao(second).getAll(), hasLength(2));
      await (await second.database).close();
    });
  });

  group('playlists', () {
    late AppDatabase appDb;
    late PlaylistRepository repo;
    late SongDao songs;

    setUp(() async {
      appDb = AppDatabase.forTesting(path);
      repo = PlaylistRepository(PlaylistDao(appDb));
      songs = SongDao(appDb);
      for (final id in ['a', 'b', 'c']) {
        await songs.insert(_song(id));
      }
    });

    tearDown(() async {
      await (await appDb.database).close();
    });

    test('create, list sorted by name ignoring case, rename', () async {
      await repo.create('zebra');
      final b = await repo.create('Apple');
      await repo.create('  mango  ');

      var lib = await repo.getLibrary();
      expect(lib.playlists.map((x) => x.name), ['Apple', 'mango', 'zebra']);

      await repo.rename(b.id, '  Banana ');
      lib = await repo.getLibrary();
      expect(lib.playlists.map((x) => x.name), ['Banana', 'mango', 'zebra']);
    });

    test('songs keep the order they were added in', () async {
      final pl = await repo.create('Mix');
      await repo.addSong(pl.id, 'c');
      await repo.addSong(pl.id, 'a');
      await repo.addSong(pl.id, 'b');
      expect((await repo.getLibrary()).idsOf(pl.id), ['c', 'a', 'b']);
    });

    test('adding the same song twice is ignored', () async {
      final pl = await repo.create('Mix');
      expect(await repo.addSong(pl.id, 'a'), isTrue);
      expect(await repo.addSong(pl.id, 'a'), isFalse);
      expect((await repo.getLibrary()).idsOf(pl.id), ['a']);
    });

    test('the same song can be in several playlists', () async {
      final one = await repo.create('One');
      final two = await repo.create('Two');
      await repo.addSong(one.id, 'a');
      await repo.addSong(two.id, 'a');
      final lib = await repo.getLibrary();
      expect(lib.idsOf(one.id), ['a']);
      expect(lib.idsOf(two.id), ['a']);
    });

    test('removing a song keeps the order of the rest and allows re-adding',
        () async {
      final pl = await repo.create('Mix');
      for (final id in ['a', 'b', 'c']) {
        await repo.addSong(pl.id, id);
      }
      await repo.removeSong(pl.id, 'b');
      expect((await repo.getLibrary()).idsOf(pl.id), ['a', 'c']);

      await repo.addSong(pl.id, 'b'); // goes to the end
      expect((await repo.getLibrary()).idsOf(pl.id), ['a', 'c', 'b']);
    });

    test('deleting a playlist keeps its songs in the library', () async {
      final pl = await repo.create('Temp');
      await repo.addSong(pl.id, 'a');
      await repo.delete(pl.id);

      final lib = await repo.getLibrary();
      expect(lib.playlists, isEmpty);
      expect(lib.songIds, isEmpty);
      expect(await songs.getAll(), hasLength(3));
    });

    test('deleting a song removes it from every playlist', () async {
      final one = await repo.create('One');
      final two = await repo.create('Two');
      await repo.addSong(one.id, 'a');
      await repo.addSong(one.id, 'b');
      await repo.addSong(two.id, 'a');

      await songs.delete('a');

      final lib = await repo.getLibrary();
      expect(lib.idsOf(one.id), ['b']);
      expect(lib.idsOf(two.id), isEmpty);
      expect(lib.playlists, hasLength(2)); // the playlists themselves stay
    });

    test('an empty playlist has no ids', () async {
      final pl = await repo.create('Empty');
      expect((await repo.getLibrary()).idsOf(pl.id), isEmpty);
    });
  });
}
