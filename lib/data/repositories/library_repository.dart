import 'dart:io';

import '../../core/storage_paths.dart';
import '../database/song_dao.dart';
import '../models/song.dart';

/// What the rest of the app talks to for songs.
/// Screens never touch SQL or the database directly.
class LibraryRepository {
  LibraryRepository(this._songDao);

  final SongDao _songDao;

  Future<List<Song>> getSongs() => _songDao.getAll();

  Future<Song?> getSong(String id) => _songDao.getById(id);

  Future<void> addSong(Song song) => _songDao.insert(song);

  Future<void> updateSong(Song song) => _songDao.update(song);

  /// Removes the song from the library AND deletes its stored audio/artwork
  /// files. The UI must show a confirmation first. [PRD FR-006]
  /// The song's loop profile is removed automatically (ON DELETE CASCADE).
  Future<void> removeSong(Song song) async {
    await _songDao.delete(song.id);
    await _deleteFileQuietly(song.absoluteFilePath);
    final art = song.absoluteArtworkPath;
    if (art != null) await _deleteFileQuietly(art);
  }

  Future<void> _deleteFileQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // The DB row is already gone; a leftover file is not worth crashing for.
    }
  }
}
