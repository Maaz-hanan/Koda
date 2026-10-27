import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format_duration.dart';
import '../../data/models/song.dart';
import '../../providers/audio_handler_provider.dart';
import '../../providers/library_provider.dart';
import '../shared/artwork_widget.dart';
import '../playlists/playlist_actions.dart';
import '../queue/queue_screen.dart';
import '../shared/favorite_button.dart';
import 'loop_button.dart';
import 'loop_editor_sheet.dart';
import 'loop_status_panel.dart';

/// Full-screen player. [PRD FR-007, FR-040]
///
/// The Loop button sits under the playback controls. [PRD FR-041]
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
    final scheme = Theme.of(context).colorScheme;
    final artSize =
        (MediaQuery.sizeOf(context).width - 64).clamp(200.0, 360.0).toDouble();

    // The long press on the Loop button and the "Edit loop" button open the
    // same editor.
    void openEditor() => LoopEditorSheet.show(
          context,
          songId: item.id,
          durationMs: item.duration?.inMilliseconds ?? 0,
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Now Playing'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Add to playlist',
            onPressed: librarySong == null
                ? null
                : () => showAddToPlaylistSheet(context, ref, librarySong),
          ),
          IconButton(
            icon: const Icon(Icons.queue_music),
            tooltip: 'Queue',
            onPressed: () => QueueScreen.open(context),
          ),
          FavoriteButton(
            isFavorite: isFavorite,
            onChanged: (value) async {
              try {
                await ref
                    .read(songsProvider.notifier)
                    .setFavorite(item.id, value);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Could not update favorite.')));
                }
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 24),
              ArtworkWidget(
                path: item.artUri?.toFilePath(),
                size: artSize,
                radius: 16,
              ),
              const SizedBox(height: 32),
              Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                item.artist ?? 'Unknown Artist',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              _SeekBar(duration: item.duration),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    iconSize: 44,
                    tooltip: 'Previous song',
                    icon: const Icon(Icons.skip_previous),
                    onPressed: handler.skipToPrevious,
                  ),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : IconButton.filled(
                            iconSize: 40,
                            tooltip: playing ? 'Pause' : 'Play',
                            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                            onPressed: playing ? handler.pause : handler.play,
                          ),
                  ),
                  IconButton(
                    iconSize: 44,
                    tooltip: 'Next song',
                    icon: const Icon(Icons.skip_next),
                    onPressed: handler.skipToNext,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LoopButton(
                mode: repeatMode,
                onTap: handler.cycleRepeatMode,
                onLongPress: openEditor,
              ),
              const SizedBox(height: 8),
              LoopStatusPanel(status: loopStatus, onEdit: openEditor),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draggable progress bar with elapsed / total time. [PRD FR-007, FR-013]
class _SeekBar extends ConsumerStatefulWidget {
  const _SeekBar({required this.duration});
  final Duration? duration;

  @override
  ConsumerState<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<_SeekBar> {
  /// While the user is dragging, show their finger position instead of the
  /// live playback position (otherwise the thumb would fight the finger).
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
    final shownMs =
        (_dragMs ?? position.inMilliseconds.toDouble()).clamp(0.0, maxMs).toDouble();
    final scheme = Theme.of(context).colorScheme;
    final timeStyle = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);

    return Column(
      children: [
        Slider(
          value: enabled ? shownMs : 0,
          max: maxMs,
          semanticFormatterCallback: (v) => formatDurationMs(v.round()),
          onChanged: enabled ? (v) => setState(() => _dragMs = v) : null,
          onChangeEnd: (v) async {
            await ref
                .read(audioHandlerProvider)
                .seek(Duration(milliseconds: v.round()));
            if (mounted) setState(() => _dragMs = null);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDurationMs(shownMs.round()), style: timeStyle),
              Text(enabled ? formatDurationMs(totalMs) : '--:--',
                  style: timeStyle),
            ],
          ),
        ),
      ],
    );
  }
}
