import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/song.dart';
import '../data/services/import_service.dart';
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
  }
}

final songsProvider =
    AsyncNotifierProvider<LibraryNotifier, List<Song>>(LibraryNotifier.new);
