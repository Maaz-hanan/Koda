import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/audio_handler_provider.dart';
import '../now_playing/now_playing_screen.dart';
import 'artwork_widget.dart';

/// Bar at the bottom of the library showing what's playing. [PRD FR-044]
/// Tap the artwork/title to open the full Now Playing screen.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(currentMediaItemProvider).when(
          data: (v) => v,
          loading: () => null,
          error: (e, s) => null,
        );
    if (item == null) return const SizedBox.shrink();

    final playing = ref.watch(playbackStateProvider).when(
          data: (s) => s.playing,
          loading: () => false,
          error: (e, s) => false,
        );
    final handler = ref.read(audioHandlerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProgressLine(duration: item.duration),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => NowPlayingScreen.open(context),
                      child: Row(
                        children: [
                          ArtworkWidget(
                              path: item.artUri?.toFilePath(), size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(item.artist ?? 'Unknown Artist',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 32,
                    tooltip: playing ? 'Pause' : 'Play',
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: playing ? handler.pause : handler.play,
                  ),
                  IconButton(
                    iconSize: 28,
                    tooltip: 'Next song',
                    icon: const Icon(Icons.skip_next),
                    onPressed: handler.skipToNext,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin progress line. Only this small widget redraws as time passes.
class _ProgressLine extends ConsumerWidget {
  const _ProgressLine({required this.duration});
  final Duration? duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider).when(
          data: (p) => p,
          loading: () => Duration.zero,
          error: (e, s) => Duration.zero,
        );
    final total = duration?.inMilliseconds ?? 0;
    final fraction =
        total <= 0 ? 0.0 : (position.inMilliseconds / total).clamp(0.0, 1.0);
    return LinearProgressIndicator(value: fraction.toDouble(), minHeight: 2);
  }
}
