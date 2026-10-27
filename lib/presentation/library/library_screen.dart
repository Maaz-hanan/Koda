import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/import_service.dart';
import '../../data/models/playlist.dart';
import '../../domain/library/library_views.dart';
import '../../domain/library/playlist_rules.dart';
import '../../domain/library/song_search.dart';
import '../../providers/audio_handler_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/search_provider.dart';
import '../playlists/playlist_list_view.dart';
import '../shared/mini_player.dart';
import 'song_list_view.dart';

/// Library: import, search, and four views: Songs, Playlists, Favorites,
/// Recently Played. [PRD FR-003]
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ImportService.supportedExtensions,
    );
    if (files.isEmpty) return; // user cancelled

    final notifier = ref.read(songsProvider.notifier);
    var imported = 0;
    final errors = <String>[];

    for (final f in files) {
      final path = f.path;
      if (path == null) {
        errors.add('Could not access "${f.name}".');
        continue;
      }
      try {
        await notifier.importFile(sourcePath: path, originalName: f.name);
        imported++;
      } on ImportException catch (e) {
        errors.add(e.message);
      }
    }

    if (!context.mounted) return;
    final buffer = StringBuffer();
    if (imported > 0) {
      buffer.write('Imported $imported song${imported == 1 ? '' : 's'}. ');
    }
    if (errors.isNotEmpty) buffer.write(errors.join(' '));
    _snack(context, buffer.toString().trim());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(songsProvider);
    final query = ref.watch(searchQueryProvider);
    final playlistLibrary = ref.watch(playlistsProvider).maybeWhen<PlaylistLibrary>(
          data: (v) => v,
          orElse: () => const PlaylistLibrary.empty(),
        );

    // A song just started playing: reload so "last played" is up to date.
    ref.listen<AsyncValue<String>>(songPlayedProvider, (previous, next) {
      next.whenData((_) => ref.read(songsProvider.notifier).refresh());
    });

    // Show playback problems (e.g. a damaged file) as a message.
    ref.listen<AsyncValue<String>>(playbackErrorProvider, (previous, next) {
      next.whenData((message) => _snack(context, message));
    });

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Import music',
              onPressed: () => _import(context, ref),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Songs'),
              Tab(text: 'Playlists'),
              Tab(text: 'Favorites'),
              Tab(text: 'Recently Played'),
            ],
          ),
        ),
        bottomNavigationBar: const MiniPlayer(),
        body: songs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load your library.\n$e',
                  textAlign: TextAlign.center),
            ),
          ),
          data: (all) {
            if (all.isEmpty) {
              return _EmptyState(onImport: () => _import(context, ref));
            }
            final q = query.trim();
            String noMatch(String what) => 'No $what match "$q".';

            return Column(
              children: [
                const _SearchField(),
                Expanded(
                  child: TabBarView(
                    children: [
                      SongListView(
                        songs: filterSongs(all, query),
                        emptyMessage: noMatch('songs'),
                      ),
                      PlaylistListView(
                        library: playlistLibrary,
                        playlists:
                            filterPlaylists(playlistLibrary.playlists, query),
                        hasQuery: q.isNotEmpty,
                      ),
                      SongListView(
                        songs: filterSongs(favoriteSongs(all), query),
                        emptyMessage: q.isEmpty
                            ? 'No favorites yet.\nTap the heart on a song to add it.'
                            : noMatch('favorites'),
                      ),
                      SongListView(
                        songs: filterSongs(recentlyPlayedSongs(all), query),
                        emptyMessage: q.isEmpty
                            ? 'Nothing played yet.\nSongs you play will show up here.'
                            : noMatch('recent songs'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = ref.watch(searchQueryProvider).isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SearchBar(
        controller: _controller,
        hintText: 'Search songs, artists, albums',
        leading: const Icon(Icons.search),
        trailing: [
          if (hasText)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear search',
              onPressed: () {
                _controller.clear();
                ref.read(searchQueryProvider.notifier).set('');
              },
            ),
        ],
        onChanged: (value) => ref.read(searchQueryProvider.notifier).set(value),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music_outlined,
                size: 72, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Your library is empty',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Import MP3, M4A, AAC or WAV files from the Files app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add),
              label: const Text('Import music'),
            ),
          ],
        ),
      ),
    );
  }
}
