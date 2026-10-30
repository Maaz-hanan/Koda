import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format_duration.dart';
import '../../core/haptics.dart';
import '../../data/models/song.dart';
import '../../providers/audio_handler_provider.dart';
import '../../providers/library_provider.dart';
import '../playlists/playlist_actions.dart';
import '../queue/queue_screen.dart';
import '../shared/artwork_widget.dart';
import '../shared/circle_icon_button.dart';
import '../shared/scrub_bar.dart';
import '../theme/app_theme.dart';
import 'loop_button.dart';
import 'loop_editor_sheet.dart';
import 'loop_status_panel.dart';
import 'now_playing_background.dart';
import 'shuffle_button.dart';
import 'volume_slider.dart';

/// Full-screen player. [PRD FR-007, FR-040]
///
/// Apple-Music-inspired: a background tinted by the artwork, a grabber to
/// close, artwork that shrinks when paused, bare transport buttons, the loop
/// status, a volume bar and a row of glass buttons.
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  /// Opens this screen sliding up from the bottom.
  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => const NowPlayingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If playback is stopped (song removed, file damaged), close this screen.
    ref.listen<AsyncValue<MediaItem?>>(currentMediaItemProvider, (prev, next) {
      next.whenData((item) {
        if (item == null) Navigator.of(context).maybePop();
      });
    });

    final item = ref.watch(currentMediaItemProvider).when<MediaItem?>(
          data: (v) => v,
          loading: () => null,
          error: (e, s) => null,
        );
    if (item == null) return const Scaffold(body: SizedBox.shrink());

    final state = ref.watch(playbackStateProvider).when<PlaybackState?>(
          data: (s) => s,
          loading: () => null,
          error: (e, s) => null,
        );
    final playing = state?.playing ?? false;
    final loading = state?.processingState == AudioProcessingState.loading ||
        state?.processingState == AudioProcessingState.buffering;

    final handler = ref.read(audioHandlerProvider);
    final repeatMode = ref.watch(repeatModeProvider);
    final loopStatus = ref.watch(loopStatusProvider);
    final shuffleOn = ref.watch(shuffleProvider);
    final volume = ref.watch(volumeProvider);
    // The queue holds a copy of the song, so ask the library (always fresh)
    // about this song: is it a favorite, and which Song to add to a playlist.
    final librarySong = ref.watch(songsProvider).maybeWhen<Song?>(
          data: (songs) {
            for (final s in songs) {
              if (s.id == item.id) return s;
            }
            return null;
          },
          orElse: () => null,
        );
    final isFavorite = librarySong?.isFavorite ?? false;
    final artPath = item.artUri?.toFilePath();

    // The long press on the Loop button and the "Edit loop" button open the
    // same editor.
    void openEditor() => LoopEditorSheet.show(
          context,
          songId: item.id,
          durationMs: item.duration?.inMilliseconds ?? 0,
        );

    Future<void> toggleFavorite() async {
      // A soft tap when a heart is added, a lighter tick when removed.
      if (isFavorite) {
        Haptics.tick();
      } else {
        Haptics.light();
      }
      try {
        await ref
            .read(songsProvider.notifier)
            .setFavorite(item.id, !isFavorite);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not update favorite.')));
        }
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: NowPlayingBackground(
          artworkPath: artPath,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final artSize = math
                    .max(
                      120.0,
                      math.min(
                        math.min(constraints.maxWidth - 48, 340.0),
                        constraints.maxHeight * 0.38,
                      ),
                    )
                    .toDouble();

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            _Grabber(onClose: () => Navigator.of(context).pop()),
                            const Spacer(),
                            AnimatedScale(
                              scale: playing ? 1.0 : 0.86,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutBack,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.nowPlayingArtwork),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color.fromRGBO(0, 0, 0, 0.35),
                                      blurRadius: 30,
                                      offset: Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: ArtworkWidget(
                                  path: artPath,
                                  size: artSize,
                                  radius: AppRadius.nowPlayingArtwork,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.nowPlayingTitle,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.artist ?? 'Unknown Artist',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.nowPlayingArtist,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                CircleIconButton(
                                  icon: isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  active: isFavorite,
                                  activeColor: AppColors.favoriteOn,
                                  tooltip: isFavorite
                                      ? 'Remove from favorites'
                                      : 'Add to favorites',
                                  onPressed: toggleFavorite,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _SeekArea(duration: item.duration),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  iconSize: 44,
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Previous song',
                                  icon: const Icon(Icons.fast_rewind_rounded,
                                      color: AppColors.textPrimary),
                                  onPressed: () {
                                    Haptics.light();
                                    handler.skipToPrevious();
                                  },
                                ),
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: loading
                                      ? const Center(
                                          child: SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: CircularProgressIndicator(
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        )
                                      : IconButton(
                                          iconSize: 60,
                                          padding: EdgeInsets.zero,
                                          tooltip: playing ? 'Pause' : 'Play',
                                          icon: Icon(
                                            playing
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            color: AppColors.textPrimary,
                                          ),
                                          onPressed: () {
                                            Haptics.light();
                                            playing
                                                ? handler.pause()
                                                : handler.play();
                                          },
                                        ),
                                ),
                                IconButton(
                                  iconSize: 44,
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Next song',
                                  icon: const Icon(Icons.fast_forward_rounded,
                                      color: AppColors.textPrimary),
                                  onPressed: () {
                                    Haptics.light();
                                    handler.skipToNext();
                                  },
                                ),
                              ],
                            ),
                            const Spacer(),
                            LoopStatusPanel(
                              status: loopStatus,
                              onEdit: () {
                                Haptics.tick();
                                openEditor();
                              },
                            ),
                            const SizedBox(height: 12),
                            VolumeSlider(
                              value: volume,
                              onChanged: (v) =>
                                  handler.setVolume(v, save: false),
                              onChangeEnd: (v) => handler.setVolume(v),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ShuffleButton(
                                  isOn: shuffleOn,
                                  onPressed: () {
                                    Haptics.tick();
                                    handler.toggleShuffle();
                                  },
                                ),
                                LoopButton(
                                  mode: repeatMode,
                                  onTap: () {
                                    Haptics.tick();
                                    handler.cycleRepeatMode();
                                  },
                                  onLongPress: () {
                                    Haptics.medium();
                                    openEditor();
                                  },
                                ),
                                CircleIconButton(
                                  icon: Icons.playlist_add,
                                  tooltip: 'Add to playlist',
                                  onPressed: librarySong == null
                                      ? null
                                      : () => showAddToPlaylistSheet(
                                          context, ref, librarySong),
                                ),
                                CircleIconButton(
                                  icon: Icons.queue_music,
                                  tooltip: 'Queue',
                                  onPressed: () => QueueScreen.open(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The small pill at the top. Tap it or swipe down to close.
class _Grabber extends StatelessWidget {
  const _Grabber({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 300) onClose();
      },
      child: Semantics(
        button: true,
        label: 'Close',
        excludeSemantics: true,
        onTap: onClose,
        child: SizedBox(
          height: 44,
          width: double.infinity,
          child: Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Position bar with elapsed / total time. [PRD FR-007, FR-013]
class _SeekArea extends ConsumerStatefulWidget {
  const _SeekArea({required this.duration});
  final Duration? duration;

  @override
  ConsumerState<_SeekArea> createState() => _SeekAreaState();
}

class _SeekAreaState extends ConsumerState<_SeekArea> {
  /// While the user is dragging, show their finger position instead of the
  /// live playback position (otherwise the bar would fight the finger).
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(positionProvider).when(
          data: (p) => p,
          loading: () => Duration.zero,
          error: (e, s) => Duration.zero,
        );

    final totalMs = widget.duration?.inMilliseconds ?? 0;
    final enabled = totalMs > 0;
    final maxMs = enabled ? totalMs.toDouble() : 1.0;
    final shownMs = (_dragMs ?? position.inMilliseconds.toDouble())
        .clamp(0.0, maxMs)
        .toDouble();

    return Column(
      children: [
        ScrubBar(
          value: enabled ? shownMs : 0,
          max: maxMs,
          enabled: enabled,
          semanticLabel: 'Song position',
          semanticFormat: (v) => formatDurationMs(v.round()),
          onChanged: (v) => setState(() => _dragMs = v),
          onChangeEnd: (v) async {
            await ref
                .read(audioHandlerProvider)
                .seek(Duration(milliseconds: v.round()));
            if (mounted) setState(() => _dragMs = null);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatDurationMs(shownMs.round()), style: AppText.caption),
            Text(enabled ? formatDurationMs(totalMs) : '--:--',
                style: AppText.caption),
          ],
        ),
      ],
    );
  }
}
