import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
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
import '../theme/app_theme.dart';
import 'library_bottom_bar.dart';
import 'song_list_view.dart';

/// Library: a large title, import, search, and four views you can swipe
/// between or pick with the chips: Songs, Playlists, Favorites, Recently
/// Played. [PRD FR-003]
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  /// True while the bottom tabs are collapsed (set by scrolling a list down).
  final ValueNotifier<bool> _collapsed = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: LibraryTab.all.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _collapsed.dispose();
    super.dispose();
  }

  /// Scrolling a list down collapses the tabs, scrolling up opens them
  /// again (like Apple Music). Only vertical scrolling counts.
  bool _onScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.direction == ScrollDirection.reverse) {
      _collapsed.value = true;
    } else if (n.direction == ScrollDirection.forward) {
      _collapsed.value = false;
    }
    return false;
  }

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
  Widget build(BuildContext context) {
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
        // Light status bar icons on the black background.
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          // Lists scroll under the floating mini player and keep their last
          // row clear of it.
          extendBody: true,
          bottomNavigationBar:
              LibraryBottomBar(controller: _tabs, collapsed: _collapsed),
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
                          const SizedBox(height: 8),
                          Expanded(
                            child: NotificationListener<UserScrollNotification>(
                              onNotification: _onScroll,
                              child: TabBarView(
                              controller: _tabs,
                              children: [
                                SongListView(
                                  songs: shownSongs,
                                  emptyMessage: noMatch('songs'),
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
            onPressed: () {
              Haptics.tick();
              onImport();
            },
          ),
        ],
      ),
    );
  }
}
