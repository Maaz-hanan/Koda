import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../providers/audio_handler_provider.dart';
import '../now_playing/now_playing_screen.dart';
import '../theme/app_theme.dart';
import 'artwork_widget.dart';
import 'glass_container.dart';

/// The floating glass pill that shows what is playing. [PRD FR-044]
/// Tap the artwork or title to open Now Playing.
///
/// It hangs at the bottom of a screen (`bottomNavigationBar`). Screens that
/// show a list under it must set `extendBody: true`, so the list scrolls
/// under the glass and automatically keeps its last row clear of the pill.
/// Nothing is drawn when no song is loaded.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, this.embedded = false, this.showSkip = true});

  /// Height of the pill itself.
  static const double height = 60;

  /// Height when [embedded] in the library's bottom bar (same as its buttons).
  static const double embeddedHeight = 56;

  /// True: only the glass pill, with no outer padding or safe area, so a
  /// parent (the library bottom bar) can place it. False: the pill hangs at
  /// the bottom of a screen as `bottomNavigationBar`.
  final bool embedded;

  /// Show the "next song" button (the collapsed bottom bar hides it to save
  /// room, like Apple Music).
  final bool showSkip;

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

    final pill = SizedBox(
          height: embedded ? embeddedHeight : height,
          child: GlassContainer(
            radius: AppRadius.glassMiniPlayer,
            shadow: true,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => NowPlayingScreen.open(context),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        ArtworkWidget(
                          path: item.artUri?.toFilePath(),
                          size: 40,
                          radius: 8,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                item.artist ?? 'Unknown Artist',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  iconSize: 28,
                  tooltip: playing ? 'Pause' : 'Play',
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  onPressed: () {
                    Haptics.light();
                    final handler = ref.read(audioHandlerProvider);
                    playing ? handler.pause() : handler.play();
                  },
                ),
                if (showSkip)
                  IconButton(
                    iconSize: 26,
                    tooltip: 'Next song',
                    icon: const Icon(Icons.skip_next),
                    onPressed: () {
                      Haptics.light();
                      ref.read(audioHandlerProvider).skipToNext();
                    },
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
    );

    if (embedded) return pill;
    return SafeArea(
      top: false,
      child: Padding(
        // 12 pt of air above the pill, 12 at the sides, 8 above the bottom.
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: pill,
      ),
    );
  }
}
