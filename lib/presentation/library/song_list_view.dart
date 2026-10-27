import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage_paths.dart';
import '../../data/models/song.dart';
import '../../providers/audio_handler_provider.dart';
import '../shared/artwork_widget.dart';
import '../shared/favorite_button.dart';
import '../playlists/playlist_actions.dart';
import 'list_message.dart';
import 'song_actions.dart';

/// A list of songs. Tapping a song plays THIS list as the queue, starting at
/// that song. Used by the Songs, Favorites and Recently Played tabs and by
/// the album / artist / playlist screens.
class SongListView extends ConsumerWidget {
  const SongListView({
    super.key,
    required this.songs,
    required this.emptyMessage,
    this.playlistId,
  });

  final List<Song> songs;

  /// Set when this list IS a playlist: the menu then says "Remove from
  /// playlist" (no confirmation, the song stays in the library) and a long
  /// press does nothing. Null everywhere else: "Remove from library".
  final String? playlistId;

  /// Shown when [songs] is empty.
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) return ListMessage(emptyMessage);

    final currentId = ref.watch(currentMediaItemProvider).when<String?>(
          data: (m) => m?.id,
          loading: () => null,
          error: (e, s) => null,
        );

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: songs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final song = songs[i];
        return SongTile(
          song: song,
          isCurrent: song.id == currentId,
          onTap: () => ref.read(audioHandlerProvider).playQueue(songs, i),
          onRemove: playlistId == null
              ? () => confirmAndRemoveSong(context, ref, song)
              : () => removeSongFromPlaylist(context, ref, playlistId!, song),
          removeLabel: playlistId == null
              ? 'Remove from library'
              : 'Remove from playlist',
          longPressRemoves: playlistId == null,
          onFavoriteChanged: (value) =>
              setSongFavorite(context, ref, song.id, value),
          onAddToPlaylist: () => showAddToPlaylistSheet(context, ref, song),
          onPlayNext: () => playNextWithMessage(context, ref, song),
          onAddToQueue: () => addToQueueWithMessage(context, ref, song),
        );
      },
    );
  }
}

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.onTap,
    required this.onRemove,
    required this.onFavoriteChanged,
    this.onAddToPlaylist,
    this.onPlayNext,
    this.onAddToQueue,
    this.removeLabel = 'Remove from library',
    this.longPressRemoves = true,
  });

  final Song song;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final ValueChanged<bool> onFavoriteChanged;

  /// Adds an "Add to playlist" item to the ⋮ menu when set.
  final VoidCallback? onAddToPlaylist;

  /// "Play next" / "Add to queue" items in the ⋮ menu when set.
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;

  /// Text of the remove item (library vs. playlist).
  final String removeLabel;

  /// Whether a long press triggers [onRemove].
  final bool longPressRemoves;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: ArtworkWidget(path: song.absoluteArtworkPath),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrent
            ? TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)
            : null,
      ),
      subtitle:
          Text(song.displayArtist, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
      onLongPress: longPressRemoves ? onRemove : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FavoriteButton(
              isFavorite: song.isFavorite, onChanged: onFavoriteChanged),
          Text(_formatDuration(song.durationMs)),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              switch (value) {
                case 'next':
                  onPlayNext?.call();
                case 'queue':
                  onAddToQueue?.call();
                case 'playlist':
                  onAddToPlaylist?.call();
                default:
                  onRemove();
              }
            },
            itemBuilder: (context) => [
              if (onPlayNext != null)
                const PopupMenuItem(value: 'next', child: Text('Play next')),
              if (onAddToQueue != null)
                const PopupMenuItem(
                    value: 'queue', child: Text('Add to queue')),
              if (onAddToPlaylist != null)
                const PopupMenuItem(
                    value: 'playlist', child: Text('Add to playlist...')),
              PopupMenuItem(value: 'remove', child: Text(removeLabel)),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int ms) {
    if (ms <= 0) return '--:--';
    final total = ms ~/ 1000;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
  }
}
