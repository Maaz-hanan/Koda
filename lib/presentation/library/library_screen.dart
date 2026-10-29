import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../data/models/playlist.dart';
import '../../data/services/import_service.dart';
import '../../domain/library/library_views.dart';
import '../../domain/library/playlist_rules.dart';
import '../../domain/library/song_search.dart';
import '../../providers/audio_handler_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/search_provider.dart';
import '../playlists/playlist_list_view.dart';
import '../shared/circle_icon_button.dart';
import '../shared/empty_state.dart';
import '../shared/mini_player.dart';
import '../shared/pill_chip_row.dart';
import '../shared/shuffle_play_button.dart';
import '../theme/app_theme.dart';
import 'song_list_view.dart';

/// Library: a large title, import, search, and four views you can swipe
/// between or pick with the chips: Songs, Playlists, Favorites, Recently
/// Played. [PRD FR-003]
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
      length: _SectionChips.labels.length,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Light status bar icons on the black background.
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          // Lists scroll under the floating mini player and keep their last
          // row clear of it.
          extendBody: true,
          bottomNavigationBar: const MiniPlayer(),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _LibraryHeader(onImport: () => _import(context, ref)),
                Expanded(
                  child: songs.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Could not load your library.\n$e',
                            textAlign: TextAlign.center),
                      ),
                    ),
                    data: (all) {
                      if (all.isEmpty) {
                        return EmptyState(
                          icon: Icons.library_music_outlined,
                          title: 'Your library is empty',
                          message:
                              'Import MP3, M4A, AAC or WAV files from the Files app.',
                          actionLabel: 'Import music',
                          onAction: () => _import(context, ref),
                        );
                      }
                      final q = query.trim();
                      String noMatch(String what) => 'No $what match "$q".';
                      final shownSongs = filterSongs(all, query);

                      return Column(
                        children: [
                          const _SearchField(),
                          const _SectionChips(),
                          const SizedBox(height: 8),
                          Expanded(
                            child: TabBarView(
                              children: [
                                Column(
                                  children: [
                                    if (shownSongs.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            AppSpacing.pageMargin, 0,
                                            AppSpacing.pageMargin, 8),
                                        child: Row(
                                          children: [
                                            ShufflePlayButton(
                                              onPressed: () {
                                                Haptics.light();
                                                ref
                                                    .read(audioHandlerProvider)
                                                    .playShuffled(shownSongs);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    Expanded(
                                      child: SongListView(
                                        songs: shownSongs,
                                        emptyMessage: noMatch('songs'),
                                      ),
                                    ),
                                  ],
                                ),
                                PlaylistListView(
                                  library: playlistLibrary,
                                  playlists: filterPlaylists(
                                      playlistLibrary.playlists, query),
                                  hasQuery: q.isNotEmpty,
                                  allSongs: all,
                                ),
                                SongListView(
                                  songs: filterSongs(favoriteSongs(all), query),
                                  emptyIcon: Icons.favorite_border,
                                  emptyMessage: q.isEmpty
                                      ? 'No favorites yet.\nTap the heart on a song to add it.'
                                      : noMatch('favorites'),
                                ),
                                SongListView(
                                  songs: filterSongs(
                                      recentlyPlayedSongs(all), query),
                                  emptyIcon: Icons.history,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The large "Library" title with the glass "+" import button.
class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMargin, 8, AppSpacing.pageMargin, 8),
      child: Row(
        children: [
          const Expanded(child: Text('Library', style: AppText.largeTitle)),
          CircleIconButton(
            icon: Icons.add,
            active: true,
            tooltip: 'Import music',
            onPressed: onImport,
          ),
        ],
      ),
    );
  }
}

/// The pill chips that pick the section. They follow the swipe between
/// pages, and a tap on a chip moves the pages.
class _SectionChips extends StatelessWidget {
  const _SectionChips();

  static const labels = ['Songs', 'Playlists', 'Favorites', 'Recently Played'];

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    final animation = controller.animation;
    return ListenableBuilder(
      listenable: animation ?? controller,
      builder: (context, _) {
        final position = animation?.value ?? controller.index.toDouble();
        final selected = position.round().clamp(0, labels.length - 1);
        return PillChipRow(
          labels: labels,
          selectedIndex: selected,
          onSelected: (i) {
            Haptics.tick();
            controller.animateTo(i);
          },
        );
      },
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
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMargin, 4, AppSpacing.pageMargin, 12),
      child: SearchBar(
        controller: _controller,
        hintText: 'Search songs, artists, albums',
        leading: const Icon(Icons.search, color: AppColors.textSecondary),
        trailing: [
          if (hasText)
            IconButton(
              icon: const Icon(Icons.clear, color: AppColors.textSecondary),
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
