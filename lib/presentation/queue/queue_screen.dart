import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../data/models/song.dart';
import '../../domain/loop/loop_mode.dart';
import '../../domain/playback/queue_position.dart';
import '../../providers/audio_handler_provider.dart';
import '../../providers/library_provider.dart';
import '../library/list_message.dart';
import '../now_playing/loop_editor_sheet.dart';
import '../now_playing/now_playing_background.dart';
import '../playlists/playlist_actions.dart';
import '../shared/artwork_widget.dart';
import '../shared/circle_icon_button.dart';
import '../shared/equalizer_icon.dart';
import '../theme/app_theme.dart';

/// The queue: every song in play order. Tap a song to jump to it, tap the
/// X to take it out of the queue. [PRD FR-008, FR-045]
///
/// The song that is playing is highlighted and has no X: removing it would
/// silently stop the music, so it stays until you pick another song.
class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const QueueScreen()),
    );
  }

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  static const double _rowHeight = AppSpacing.rowHeight;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    // Open with the playing song near the top, not lost at the bottom of a
    // long queue.
    final queue = ref.read(queueProvider).maybeWhen<List<MediaItem>>(
          data: (v) => v,
          orElse: () => const [],
        );
    final currentId = ref.read(currentMediaItemProvider).maybeWhen<String?>(
          data: (m) => m?.id,
          orElse: () => null,
        );
    final i = indexOfSong(queue.map((m) => m.id).toList(), currentId);
    _scroll = ScrollController(
      initialScrollOffset: math.max(0, (i - 1) * _rowHeight),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(queueProvider).maybeWhen<List<MediaItem>>(
          data: (v) => v,
          orElse: () => const [],
        );
    final currentId = ref.watch(currentMediaItemProvider).maybeWhen<String?>(
          data: (m) => m?.id,
          orElse: () => null,
        );
    final playing = ref.watch(playbackStateProvider).maybeWhen<bool>(
          data: (s) => s.playing,
          orElse: () => false,
        );
    final current = ref.watch(currentMediaItemProvider).maybeWhen<MediaItem?>(
          data: (m) => m,
          orElse: () => null,
        );
    final shuffleOn = ref.watch(shuffleProvider);
    final repeatMode = ref.watch(repeatModeProvider);
    // The queue holds a copy of the song; the library is always fresh.
    final librarySong = ref.watch(songsProvider).maybeWhen<Song?>(
          data: (songs) {
            for (final s in songs) {
              if (s.id == currentId) return s;
            }
            return null;
          },
          orElse: () => null,
        );
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Queue'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: NowPlayingBackground(
        artworkPath: current?.artUri?.toFilePath(),
        child: queue.isEmpty
            ? Padding(
                padding: EdgeInsets.only(top: topInset),
                child: const ListMessage(
                    'The queue is empty.\nPlay a song from your library.'),
              )
            : Column(
                children: [
                  SizedBox(height: topInset + 8),
                  if (current != null)
                    _Header(
                      item: current,
                      isFavorite: librarySong?.isFavorite ?? false,
                      onFavorite: () {
                        final fav = librarySong?.isFavorite ?? false;
                        fav ? Haptics.tick() : Haptics.light();
                        ref
                            .read(songsProvider.notifier)
                            .setFavorite(current.id, !fav);
                      },
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageMargin),
                      children: [
                        _Pill(
                          icon: Icons.shuffle,
                          label: 'Shuffle',
                          selected: shuffleOn,
                          onTap: () {
                            Haptics.tick();
                            ref.read(audioHandlerProvider).toggleShuffle();
                          },
                        ),
                        const SizedBox(width: 8),
                        _Pill(
                          icon: repeatMode == LoopMode.repeatOnce
                              ? Icons.repeat_one
                              : Icons.repeat,
                          label: 'Loop',
                          selected: repeatMode != LoopMode.off,
                          onTap: () {
                            Haptics.tick();
                            ref.read(audioHandlerProvider).cycleRepeatMode();
                          },
                        ),
                        const SizedBox(width: 8),
                        _Pill(
                          icon: Icons.tune,
                          label: 'Edit loop',
                          onTap: current == null
                              ? null
                              : () {
                                  Haptics.tick();
                                  LoopEditorSheet.show(
                                    context,
                                    songId: current.id,
                                    durationMs:
                                        current.duration?.inMilliseconds ?? 0,
                                  );
                                },
                        ),
                        const SizedBox(width: 8),
                        _Pill(
                          icon: Icons.playlist_add,
                          label: 'Add to playlist',
                          onTap: librarySong == null
                              ? null
                              : () => showAddToPlaylistSheet(
                                  context, ref, librarySong),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.pageMargin, 24,
                        AppSpacing.pageMargin, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Up Next', style: AppText.sectionTitle),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: EdgeInsets.zero,
                      itemExtent: _rowHeight,
                      itemCount: queue.length,
                      itemBuilder: (context, i) {
                        final item = queue[i];
                        final isCurrent = item.id == currentId;
                        return ListTile(
                          contentPadding: const EdgeInsets.only(
                              left: AppSpacing.pageMargin, right: 4),
                          leading: ArtworkWidget(
                            path: item.artUri?.toFilePath(),
                            size: AppSpacing.rowArtwork,
                            radius: AppRadius.rowArtwork,
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: isCurrent
                                ? AppText.rowTitle
                                    .copyWith(color: AppColors.accent)
                                : AppText.rowTitle,
                          ),
                          subtitle: Text(item.artist ?? 'Unknown Artist',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.rowSubtitle),
                          // Both the moving bars and the X sit in the SAME
                          // 48 x 48 box, so they line up exactly.
                          trailing: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: isCurrent
                                  ? EqualizerIcon(
                                      animating: playing,
                                      color: AppColors.accent)
                                  : IconButton(
                                      icon: const Icon(Icons.close),
                                      iconSize: 20,
                                      color: AppColors.textTertiary,
                                      tooltip: 'Remove from queue',
                                      onPressed: () {
                                        Haptics.light();
                                        ref.read(audioHandlerProvider).removeFromQueue(item.id);
                                      },
                                    ),
                            ),
                          ),
                          onTap: isCurrent
                              ? null
                              : () {
                                  Haptics.tick();
                                  ref.read(audioHandlerProvider).skipToQueueItem(i);
                                },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The song that is playing: 56 pt artwork, title, artist and the heart.
class _Header extends StatelessWidget {
  const _Header({
    required this.item,
    required this.isFavorite,
    required this.onFavorite,
  });

  final MediaItem item;
  final bool isFavorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
      child: Row(
        children: [
          ArtworkWidget(
              path: item.artUri?.toFilePath(), size: 56, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.rowTitle
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(item.artist ?? 'Unknown Artist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.rowSubtitle),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CircleIconButton(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            active: isFavorite,
            activeColor: AppColors.favoriteOn,
            tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: onFavorite,
          ),
        ],
      ),
    );
  }
}

/// A small pill button under the header. Selected = light fill, dark text.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = !enabled
        ? AppColors.textTertiary
        : selected
            ? AppColors.background
            : AppColors.textPrimary;
    return Material(
      color: selected ? AppColors.chipSelected : AppColors.chipUnselected,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
