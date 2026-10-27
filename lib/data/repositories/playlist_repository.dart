import 'package:uuid/uuid.dart';

import '../database/playlist_dao.dart';
import '../models/playlist.dart';

/// What the rest of the app talks to for playlists.
class PlaylistRepository {
  PlaylistRepository(this._dao);

  final PlaylistDao _dao;

  static const _uuid = Uuid();

  Future<PlaylistLibrary> getLibrary() async {
    final playlists = await _dao.getAll();
    final ids = await _dao.getAllSongIds();
    return PlaylistLibrary(playlists: playlists, songIds: ids);
  }

  /// The caller validates the name first (see validatePlaylistName).
  Future<Playlist> create(String name) async {
    final playlist = Playlist(
      id: _uuid.v4(),
      name: name.trim(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _dao.insert(playlist);
    return playlist;
  }

  Future<void> rename(String id, String name) => _dao.rename(id, name.trim());

  Future<void> delete(String id) => _dao.delete(id);

  /// False if the song was already in the playlist.
  Future<bool> addSong(String playlistId, String songId) => _dao.addSong(
      playlistId, songId, DateTime.now().millisecondsSinceEpoch);

  Future<void> setOrder(String playlistId, List<String> orderedSongIds) =>
      _dao.setOrder(playlistId, orderedSongIds);

  Future<void> removeSong(String playlistId, String songId) =>
      _dao.removeSong(playlistId, songId);
}
