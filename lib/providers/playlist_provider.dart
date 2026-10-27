import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/playlist_dao.dart';
import '../data/models/playlist.dart';
import '../data/repositories/playlist_repository.dart';
import 'repository_providers.dart';

final playlistRepositoryProvider = Provider<PlaylistRepository>(
  (ref) => PlaylistRepository(PlaylistDao(ref.watch(appDatabaseProvider))),
);

/// All playlists and their songs. Every change reloads everything and swaps
/// the state in one go, so screens never flash empty. [PRD FR-003]
class PlaylistsNotifier extends AsyncNotifier<PlaylistLibrary> {
  @override
  Future<PlaylistLibrary> build() =>
      ref.read(playlistRepositoryProvider).getLibrary();

  PlaylistRepository get _repo => ref.read(playlistRepositoryProvider);

  /// Reloads from the database (e.g. after a song was removed from the
  /// library, which also removes it from every playlist).
  Future<void> refresh() async {
    state = AsyncData(await _repo.getLibrary());
  }

  Future<Playlist> create(String name) async {
    final playlist = await _repo.create(name);
    await refresh();
    return playlist;
  }

  Future<void> rename(String id, String name) async {
    await _repo.rename(id, name);
    await refresh();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await refresh();
  }

  /// False if the song was already in the playlist.
  Future<bool> addSong(String playlistId, String songId) async {
    final added = await _repo.addSong(playlistId, songId);
    if (added) await refresh();
    return added;
  }

  /// Saves a new song order. The screen changes IMMEDIATELY (so a dropped row
  /// does not jump back), then the database is written; if that fails the
  /// real order is reloaded and the error is passed on.
  Future<void> reorder(String playlistId, List<String> orderedSongIds) async {
    final current = state.value;
    if (current != null) {
      state = AsyncData(PlaylistLibrary(
        playlists: current.playlists,
        songIds: {...current.songIds, playlistId: orderedSongIds},
      ));
    }
    try {
      await _repo.setOrder(playlistId, orderedSongIds);
    } catch (_) {
      await refresh();
      rethrow;
    }
  }

  Future<void> removeSong(String playlistId, String songId) async {
    await _repo.removeSong(playlistId, songId);
    await refresh();
  }
}

final playlistsProvider =
    AsyncNotifierProvider<PlaylistsNotifier, PlaylistLibrary>(
        PlaylistsNotifier.new);
