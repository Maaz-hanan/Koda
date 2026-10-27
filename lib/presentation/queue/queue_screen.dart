import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/playback/queue_position.dart';
import '../../providers/audio_handler_provider.dart';
import '../library/list_message.dart';
import '../shared/artwork_widget.dart';

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
  static const double _rowHeight = 72;
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Queue')),
      body: queue.isEmpty
          ? const ListMessage('The queue is empty.\nPlay a song from your library.')
          : ListView.builder(
              controller: _scroll,
              itemExtent: _rowHeight,
              itemCount: queue.length,
              itemBuilder: (context, i) {
                final item = queue[i];
                final isCurrent = item.id == currentId;
                return ListTile(
                  leading: ArtworkWidget(path: item.artUri?.toFilePath()),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isCurrent
                        ? TextStyle(
                            color: scheme.primary, fontWeight: FontWeight.w600)
                        : null,
                  ),
                  subtitle: Text(item.artist ?? 'Unknown Artist',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: isCurrent
                      ? Icon(Icons.graphic_eq,
                          color: scheme.primary, semanticLabel: 'Now playing')
                      : IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Remove from queue',
                          onPressed: () => ref
                              .read(audioHandlerProvider)
                              .removeFromQueue(item.id),
                        ),
                  onTap: isCurrent
                      ? null
                      : () =>
                          ref.read(audioHandlerProvider).skipToQueueItem(i),
                );
              },
            ),
    );
  }
}
