import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/song_title.dart';
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

  /// Edit song: a new [title] and/or a new cover picture copied from
  /// [coverSourcePath]. The cover is saved under a NEW file name (so cached
  /// pictures never show the old one) and the old cover file is deleted only
  /// after the database row was updated. Returns the updated song.
  Future<Song> editSong(
    Song song, {
    String? title,
    String? coverSourcePath,
  }) async {
    var updated = await _songDao.getById(song.id) ?? song;

    if (title != null) {
      final clean = cleanSongTitle(title);
      if (clean == null) throw ArgumentError('The title cannot be empty.');
      updated = updated.copyWith(title: clean);
    }

    String? newCoverAbsolute;
    final oldCoverAbsolute = updated.absoluteArtworkPath;
    if (coverSourcePath != null) {
      final ext = p.extension(coverSourcePath).toLowerCase() == '.png'
          ? 'png'
          : 'jpg';
      final relative = p.join(
          'artwork', '${song.id}-${DateTime.now().millisecondsSinceEpoch}.$ext');
      await StoragePaths.ensureDir('artwork');
      newCoverAbsolute = StoragePaths.resolve(relative);
      await File(coverSourcePath).copy(newCoverAbsolute);
      updated = updated.copyWith(artworkPath: relative);
    }

    try {
      await _songDao.update(updated);
    } catch (_) {
      if (newCoverAbsolute != null) await _deleteFileQuietly(newCoverAbsolute);
      rethrow;
    }
    if (newCoverAbsolute != null && oldCoverAbsolute != null) {
      await _deleteFileQuietly(oldCoverAbsolute);
    }
    return updated;
  }

  /// Heart on / off. [PRD FR-005]
  Future<void> setFavorite(String id, bool isFavorite) =>
      _songDao.setFavorite(id, isFavorite);

  /// Remembers when a song last started playing ("Recently Played").
  Future<void> markPlayed(String id, int playedAtMs) =>
      _songDao.setLastPlayed(id, playedAtMs);

  /// Removes the song from the library AND deletes its stored audio/artwork
  /// files. The UI must show a confirmation first. [PRD FR-006]
  /// The song's loop profile is removed automatically (ON DELETE CASCADE).
  Future<void> removeSong(Song song) async {
    await _songDao.delete(song.id);
    await _deleteFileQuietly(song.absoluteFilePath);
    final art = song.absoluteArtworkPath;
    if (art != null) await _deleteFileQuietly(art);
    // Its cached waveform (if any) goes too.
    await _deleteFileQuietly(
        StoragePaths.resolve(StoragePaths.waveformRelativePath(song.id)));
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
