import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage_paths.dart';
import '../../data/models/song.dart';
import '../../providers/audio_handler_provider.dart';
import '../playlists/playlist_actions.dart';
import '../shared/artwork_widget.dart';
import '../shared/equalizer_icon.dart';
import '../shared/favorite_button.dart';
import '../theme/app_theme.dart';
import 'edit_song_sheet.dart';
import 'list_message.dart';
import 'song_actions.dart';

/// A list of songs. Tapping a song plays THIS list as the queue, starting at
/// that song. Used by the Songs, Favorites and Recently Played tabs and by
/// the playlist screens.
class SongListView extends ConsumerWidget {
  const SongListView({
    super.key,
    required this.songs,
    required this.emptyMessage,
    this.emptyIcon,
    this.playlistId,
    this.header,
  });

  final List<Song> songs;

  /// Set when this list IS a playlist: the menu then says "Remove from
  /// playlist" (no confirmation, the song stays in the library) and a long
  /// press does nothing. Null everywhere else: "Remove from library".
  final String? playlistId;

  /// Shown when [songs] is empty (see [ListMessage] for how it is laid out).
  final String emptyMessage;
  final IconData? emptyIcon;

  /// Scrolls together with the rows, above the first one (the playlist
  /// artwork + buttons). It stays visible even when [songs] is empty.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasHeader = header != null;
    if (songs.isEmpty && !hasHeader) {
      return ListMessage(emptyMessage, icon: emptyIcon);
    }

    final currentId = ref.watch(currentMediaItemProvider).when<String?>(
          data: (m) => m?.id,
          loading: () => null,
          error: (e, s) => null,
        );
    // Only rebuild the list when play <-> pause flips, not on every update.
    final playing = ref.watch(
        playbackStateProvider.select((state) => state.value?.playing ?? false));

    final headerCount = hasHeader ? 1 : 0;
    final bodyCount = songs.isEmpty ? 1 : songs.length;

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: headerCount + bodyCount,
      itemBuilder: (context, index) {
        if (hasHeader && index == 0) return header!;
        if (songs.isEmpty) {
          return SizedBox(
            height: 220,
            child: ListMessage(emptyMessage, icon: emptyIcon),
          );
        }

        final i = index - headerCount;
        final song = songs[i];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SongTile(
              song: song,
              isCurrent: song.id == currentId,
              isPlaying: playing,
              onTap: () => ref.read(audioHandlerProvider).playQueue(songs, i),
              onRemove: playlistId == null
                  ? () => confirmAndRemoveSong(context, ref, song)
                  : () =>
                      removeSongFromPlaylist(context, ref, playlistId!, song),
              removeLabel: playlistId == null
                  ? 'Remove from library'
                  : 'Remove from playlist',
              longPressRemoves: playlistId == null,
              onFavoriteChanged: (value) =>
                  setSongFavorite(context, ref, song.id, value),
              onAddToPlaylist: () =>
                  showAddToPlaylistSheet(context, ref, song),
              onPlayNext: () => playNextWithMessage(context, ref, song),
              onAddToQueue: () => addToQueueWithMessage(context, ref, song),
              onEdit: () => EditSongSheet.show(context, song),
            ),
            const Divider(
              height: 0.5,
              thickness: 0.5,
              indent: AppSpacing.listTextInset,
            ),
          ],
        );
      },
    );
  }
}

/// One song row: 64 pt tall, 48 pt artwork, title and artist, then the
/// duration, a small heart and the "..." menu. The song that is playing has
/// an accent title and moving bars over its artwork.
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.onTap,
    required this.onRemove,
    required this.onFavoriteChanged,
    this.isPlaying = false,
    this.onAddToPlaylist,
    this.onPlayNext,
    this.onAddToQueue,
    this.onEdit,
    this.removeLabel = 'Remove from library',
    this.longPressRemoves = true,
  });

  final Song song;
  final bool isCurrent;

  /// Music is actually playing (the bars move) as opposed to paused.
  final bool isPlaying;

  final VoidCallback onTap;
  final VoidCallback onRemove;
  final ValueChanged<bool> onFavoriteChanged;

  /// Adds an "Add to playlist" item to the "..." menu when set.
  final VoidCallback? onAddToPlaylist;

  /// "Play next" / "Add to queue" items in the "..." menu when set.
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;

  /// "Edit song..." (rename, change cover) in the "..." menu when set.
  final VoidCallback? onEdit;

  /// Text of the remove item (library vs. playlist).
  final String removeLabel;

  /// Whether a long press triggers [onRemove].
  final bool longPressRemoves;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: AppSpacing.rowHeight,
      minVerticalPadding: 8,
      contentPadding: const EdgeInsets.only(left: AppSpacing.pageMargin, right: 4),
      leading: _RowArtwork(
        path: song.absoluteArtworkPath,
        isCurrent: isCurrent,
        isPlaying: isPlaying,
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrent ? const TextStyle(color: AppColors.accent) : null,
      ),
      subtitle: Text(song.displayArtist,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
      onLongPress: longPressRemoves ? onRemove : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_formatDuration(song.durationMs), style: AppText.rowSubtitle),
          FavoriteButton(
            compact: true,
            isFavorite: song.isFavorite,
            onChanged: onFavoriteChanged,
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: const Icon(Icons.more_horiz),
            iconColor: AppColors.textSecondary,
            onSelected: (value) {
              switch (value) {
                case 'next':
                  onPlayNext?.call();
                case 'queue':
                  onAddToQueue?.call();
                case 'playlist':
                  onAddToPlaylist?.call();
                case 'edit':
                  onEdit?.call();
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
              if (onEdit != null)
                const PopupMenuItem(value: 'edit', child: Text('Edit song...')),
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

/// 48 pt artwork. For the current song a dark veil and the moving bars sit on
/// top of it.
class _RowArtwork extends StatelessWidget {
  const _RowArtwork({
    required this.path,
    required this.isCurrent,
    required this.isPlaying,
  });

  final String? path;
  final bool isCurrent;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.rowArtwork,
      height: AppSpacing.rowArtwork,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ArtworkWidget(
            path: path,
            size: AppSpacing.rowArtwork,
            radius: AppRadius.rowArtwork,
          ),
          if (isCurrent)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.rowArtwork),
              child: Container(
                width: AppSpacing.rowArtwork,
                height: AppSpacing.rowArtwork,
                color: const Color.fromRGBO(0, 0, 0, 0.45),
                alignment: Alignment.center,
                child: EqualizerIcon(
                  animating: isPlaying,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
