import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/storage_paths.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../domain/library/playlist_rules.dart';
import '../../providers/audio_handler_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/playlist_provider.dart';
import '../library/list_message.dart';
import '../library/song_list_view.dart';
import '../shared/artwork_widget.dart';
import '../shared/mini_player.dart';
import '../shared/shuffle_play_button.dart';
import '../theme/app_theme.dart';
import 'playlist_actions.dart';

/// One playlist: its songs, "Play all", reorder, rename and delete.
/// [PRD FR-003]
///
/// It remembers only the playlist's id and rebuilds from the live providers,
/// so hearts, renames and removals show up straight away.
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  static Future<void> open(BuildContext context, String playlistId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PlaylistDetailScreen(playlistId: playlistId),
      ),
    );
  }

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  /// True while the user is dragging songs into a new order.
  bool _reordering = false;

  // Haptics while dragging. Flutter does not say when the dragged row passes
  // another row, so we estimate it from the finger: one tick each time the
  // finger has moved about one row.
  static const double _rowHeight = 72;
  int _dragIndex = 0;
  double? _dragStartY;
  int _lastSlot = 0;
  bool _dragging = false;

  void _onDragMove(double fingerY, int songCount) {
    if (!_dragging) return;
    _dragStartY ??= fingerY;
    final raw = ((fingerY - _dragStartY!) / _rowHeight).round();
    // The row cannot move past the first or the last place.
    final slot = raw.clamp(-_dragIndex, songCount - 1 - _dragIndex).toInt();
    if (slot != _lastSlot) {
      _lastSlot = slot;
      Haptics.tick();
    }
  }

  Future<void> _onReorder(List<Song> songs, int oldIndex, int newIndex) async {
    final messenger = ScaffoldMessenger.of(context);
    final ids = moveItem([for (final s in songs) s.id], oldIndex, newIndex);
    try {
      await ref
          .read(playlistsProvider.notifier)
          .reorder(widget.playlistId, ids);
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not save the order: $e')));
    }
  }

  /// The song list while the user is reordering: drag handles, and haptics
  /// when a row is picked up, moves past another row, and is dropped.
  Widget _buildReorderList(BuildContext context, List<Song> songs) {
    return Listener(
      onPointerMove: (e) => _onDragMove(e.position.dy, songs.length),
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        // Keep the last row clear of the floating mini player.
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        itemExtent: _rowHeight,
        itemCount: songs.length,
        onReorderStart: (index) {
          _dragging = true;
          _dragIndex = index;
          _dragStartY = null;
          _lastSlot = 0;
          Haptics.medium(); // picked up
        },
        onReorderEnd: (index) {
          _dragging = false;
          Haptics.light(); // dropped
        },
        onReorderItem: (oldIndex, newIndex) =>
            _onReorder(songs, oldIndex, newIndex),
        itemBuilder: (context, i) {
          final song = songs[i];
          return ListTile(
            key: ValueKey(song.id),
            contentPadding: const EdgeInsets.only(left: AppSpacing.pageMargin),
            leading: ArtworkWidget(
              path: song.absoluteArtworkPath,
              size: AppSpacing.rowArtwork,
              radius: AppRadius.rowArtwork,
            ),
            title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(song.displayArtist,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: ReorderableDragStartListener(
              index: i,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.drag_handle, color: AppColors.textSecondary),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistId = widget.playlistId;
    final library = ref.watch(playlistsProvider).maybeWhen<PlaylistLibrary>(
          data: (v) => v,
          orElse: () => const PlaylistLibrary.empty(),
        );
    final all = ref.watch(songsProvider).maybeWhen<List<Song>>(
          data: (v) => v,
          orElse: () => const [],
        );

    final playlist = library.byId(playlistId);
    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const ListMessage('This playlist no longer exists.'),
      );
    }

    final songs = songsForIds(library.idsOf(playlistId), all);
    final canReorder = songs.length > 1;
    final reordering = _reordering && canReorder;
    final scheme = Theme.of(context).colorScheme;

    // The playlist picture: the artwork of its first song that has one.
    String? artworkPath;
    for (final song in songs) {
      if (song.artworkPath != null) {
        artworkPath = song.absoluteArtworkPath;
        break;
      }
    }

    return Scaffold(
      // Lists scroll under the floating mini player.
      extendBody: true,
      appBar: AppBar(
        actions: [
          if (canReorder)
            IconButton(
              icon: Icon(reordering ? Icons.check : Icons.swap_vert),
              tooltip: reordering ? 'Done' : 'Reorder songs',
              onPressed: () {
                Haptics.tick();
                setState(() => _reordering = !_reordering);
              },
            ),
          PopupMenuButton<String>(
            tooltip: 'Playlist options',
            onSelected: (value) {
              if (value == 'rename') {
                renamePlaylistWithPrompt(context, ref, playlist);
              } else {
                deletePlaylistWithConfirm(context, ref, playlist);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete playlist')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: reordering
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    'Drag the handles to reorder. Tap the check when done.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                Expanded(child: _buildReorderList(context, songs)),
              ],
            )
          : SongListView(
              songs: songs,
              playlistId: playlistId,
              emptyIcon: Icons.queue_music,
              emptyMessage:
                  'No songs yet.\nOpen a song\'s ... menu and choose "Add to playlist".',
              header: _PlaylistHeader(
                artworkPath: artworkPath,
                name: playlist.name,
                countText: songCountText(songs.length),
                onPlay: songs.isEmpty
                    ? null
                    : () => ref.read(audioHandlerProvider).playQueue(songs, 0),
                onShuffle: songs.isEmpty
                    ? null
                    : () {
                        Haptics.light();
                        ref.read(audioHandlerProvider).playShuffled(songs);
                      },
              ),
            ),
    );
  }
}

/// The top of a playlist screen: a 200 pt picture, the name, how many songs,
/// and the two buttons. Scrolls together with the song rows.
class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({
    required this.artworkPath,
    required this.name,
    required this.countText,
    required this.onPlay,
    required this.onShuffle,
  });

  final String? artworkPath;
  final String name;
  final String countText;

  /// Null greys the button out (an empty playlist).
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMargin, 8, AppSpacing.pageMargin, 20),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.cardArtwork),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.35),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ArtworkWidget(
              path: artworkPath,
              size: 200,
              radius: AppRadius.cardArtwork,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.sectionTitle,
          ),
          const SizedBox(height: 4),
          Text(countText, style: AppText.rowSubtitle),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play all'),
                style: FilledButton.styleFrom(minimumSize: const Size(64, 50)),
              ),
              const SizedBox(width: 12),
              ShufflePlayButton(onPressed: onShuffle),
            ],
          ),
        ],
      ),
    );
  }
}
