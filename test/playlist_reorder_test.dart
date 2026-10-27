import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/database/app_database.dart';
import 'package:loop_player/data/database/playlist_dao.dart';
import 'package:loop_player/data/database/song_dao.dart';
import 'package:loop_player/data/models/song.dart';
import 'package:loop_player/data/repositories/playlist_repository.dart';
import 'package:loop_player/domain/library/playlist_rules.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Song _song(String id) => Song(
      id: id,
      title: 'Song $id',
      durationMs: 1000,
      filePath: 'music/$id.mp3',
      importedAt: 1,
    );

void main() {
  group('moveItem', () {
    test('moves an item down: it ends up AT the new index', () {
      expect(moveItem(['a', 'b', 'c', 'd'], 0, 2), ['b', 'c', 'a', 'd']);
    });

    test('moves an item up', () {
      expect(moveItem(['a', 'b', 'c', 'd'], 3, 0), ['d', 'a', 'b', 'c']);
    });

    test('moving to the same place changes nothing', () {
      expect(moveItem(['a', 'b', 'c'], 1, 1), ['a', 'b', 'c']);
    });

    test('moving to the very end', () {
      expect(moveItem(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
    });

    test('never changes the list it was given', () {
      final original = ['a', 'b', 'c'];
      moveItem(original, 0, 2);
      expect(original, ['a', 'b', 'c']);
    });

    test('out-of-range indexes are safe', () {
      expect(moveItem(['a', 'b'], 0, 99), ['b', 'a']);
      expect(moveItem(['a', 'b'], 1, -5), ['b', 'a']);
      expect(moveItem(['a', 'b'], 5, 0), ['a', 'b']);
      expect(moveItem(<String>[], 0, 0), isEmpty);
    });
  });

  group('saving a playlist order (real SQLite)', () {
    late Directory tmp;
    late AppDatabase appDb;
    late PlaylistRepository repo;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('lp_reorder_test_');
      appDb = AppDatabase.forTesting(p.join(tmp.path, 'test.db'));
      repo = PlaylistRepository(PlaylistDao(appDb));
      final songs = SongDao(appDb);
      for (final id in ['a', 'b', 'c', 'd']) {
        await songs.insert(_song(id));
      }
    });

    tearDown(() async {
      await (await appDb.database).close();
      tmp.deleteSync(recursive: true);
    });

    test('the new order is saved and loaded back', () async {
      final pl = await repo.create('Mix');
      for (final id in ['a', 'b', 'c']) {
        await repo.addSong(pl.id, id);
      }
      await repo.setOrder(pl.id, ['c', 'a', 'b']);
      expect((await repo.getLibrary()).idsOf(pl.id), ['c', 'a', 'b']);
    });

    test('a song added after reordering goes to the end', () async {
      final pl = await repo.create('Mix');
      for (final id in ['a', 'b', 'c']) {
        await repo.addSong(pl.id, id);
      }
      await repo.setOrder(pl.id, ['c', 'b', 'a']);
      await repo.addSong(pl.id, 'd');
      expect((await repo.getLibrary()).idsOf(pl.id), ['c', 'b', 'a', 'd']);
    });

    test('reordering one playlist leaves the others alone', () async {
      final one = await repo.create('One');
      final two = await repo.create('Two');
      for (final id in ['a', 'b', 'c']) {
        await repo.addSong(one.id, id);
        await repo.addSong(two.id, id);
      }
      await repo.setOrder(one.id, ['c', 'b', 'a']);
      final lib = await repo.getLibrary();
      expect(lib.idsOf(one.id), ['c', 'b', 'a']);
      expect(lib.idsOf(two.id), ['a', 'b', 'c']);
    });

    test('the order survives removing a song and moving again', () async {
      final pl = await repo.create('Mix');
      for (final id in ['a', 'b', 'c', 'd']) {
        await repo.addSong(pl.id, id);
      }
      await repo.setOrder(pl.id, ['d', 'c', 'b', 'a']);
      await repo.removeSong(pl.id, 'c');
      expect((await repo.getLibrary()).idsOf(pl.id), ['d', 'b', 'a']);

      await repo.setOrder(pl.id, ['a', 'd', 'b']);
      expect((await repo.getLibrary()).idsOf(pl.id), ['a', 'd', 'b']);
    });

    test('an id that is not in the playlist is ignored', () async {
      final pl = await repo.create('Mix');
      await repo.addSong(pl.id, 'a');
      await repo.addSong(pl.id, 'b');
      await repo.setOrder(pl.id, ['b', 'zzz', 'a']);
      expect((await repo.getLibrary()).idsOf(pl.id), ['b', 'a']);
    });
  });
}
