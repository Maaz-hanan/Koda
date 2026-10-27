import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name, overflow: TextOverflow.ellipsis),
        actions: [
          if (canReorder)
            IconButton(
              icon: Icon(reordering ? Icons.check : Icons.swap_vert),
              tooltip: reordering ? 'Done' : 'Reorder songs',
              onPressed: () => setState(() => _reordering = !_reordering),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    reordering
                        ? 'Drag the handles to reorder. Tap the check when done.'
                        : songCountText(songs.length),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (!reordering)
                  FilledButton.icon(
                    onPressed: songs.isEmpty
                        ? null
                        : () => ref
                            .read(audioHandlerProvider)
                            .playQueue(songs, 0),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play all'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: reordering
                ? ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: songs.length,
                    onReorderItem: (oldIndex, newIndex) =>
                        _onReorder(songs, oldIndex, newIndex),
                    itemBuilder: (context, i) {
                      final song = songs[i];
                      return ListTile(
                        key: ValueKey(song.id),
                        leading: ArtworkWidget(path: song.absoluteArtworkPath),
                        title: Text(song.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(song.displayArtist,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      );
                    },
                  )
                : SongListView(
                    songs: songs,
                    playlistId: playlistId,
                    emptyMessage:
                        'No songs yet.\nOpen a song\'s ⋮ menu and choose "Add to playlist".',
                  ),
          ),
        ],
      ),
    );
  }
}
