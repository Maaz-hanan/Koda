import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/song.dart';
import '../data/services/import_service.dart';
import 'playlist_provider.dart';
import 'repository_providers.dart';

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(ref.watch(libraryRepositoryProvider)),
);

/// The list of songs shown in the library. The screen "watches" this and
/// redraws automatically whenever the list changes.
class LibraryNotifier extends AsyncNotifier<List<Song>> {
  @override
  Future<List<Song>> build() => ref.read(libraryRepositoryProvider).getSongs();

  Future<void> _reload() async {
    state = AsyncData(await ref.read(libraryRepositoryProvider).getSongs());
  }

  /// Reloads the list from the database (e.g. after a song was played).
  Future<void> refresh() => _reload();

  /// Heart on / off for one song. Updates the screen straight away after the
  /// database write succeeds. [PRD FR-005]
  Future<void> setFavorite(String songId, bool isFavorite) async {
    await ref.read(libraryRepositoryProvider).setFavorite(songId, isFavorite);
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final s in current)
        s.id == songId ? s.copyWith(isFavorite: isFavorite) : s,
    ]);
  }

  /// Edit song (title and/or cover). Reloads the list so the new title is
  /// sorted into place, and returns the updated song.
  Future<Song> editSong(
    Song song, {
    String? title,
    String? artist,
    String? coverSourcePath,
  }) async {
    final updated = await ref.read(libraryRepositoryProvider).editSong(
          song,
          title: title,
          artist: artist,
          coverSourcePath: coverSourcePath,
        );
    await _reload();
    try {
      await ref.read(playlistsProvider.notifier).refresh();
    } catch (_) {}
    return updated;
  }

  Future<Song> importFile({
    required String sourcePath,
    required String originalName,
  }) async {
    final song = await ref.read(importServiceProvider).importFile(
          sourcePath: sourcePath,
          originalName: originalName,
        );
    await _reload();
    return song;
  }

  /// Deletes the song, its stored files and its loop profile.
  /// The screen must ask for confirmation BEFORE calling this.
  Future<void> removeSong(Song song) async {
    await ref.read(libraryRepositoryProvider).removeSong(song);
    await _reload();
    // The song also left every playlist (ON DELETE CASCADE): reload them.
    try {
      await ref.read(playlistsProvider.notifier).refresh();
    } catch (_) {}
  }
}

final songsProvider =
    AsyncNotifierProvider<LibraryNotifier, List<Song>>(LibraryNotifier.new);
