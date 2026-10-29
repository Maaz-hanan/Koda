import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../data/models/song.dart';
import '../../domain/playback/queue_manager.dart';
import '../../providers/audio_handler_provider.dart';
import '../../providers/library_provider.dart';

void _snack(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Heart on / off, with a message if saving fails. [PRD FR-005]
Future<void> setSongFavorite(
  BuildContext context,
  WidgetRef ref,
  String songId,
  bool value,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final library = ref.read(songsProvider.notifier);
  try {
    await library.setFavorite(songId, value);
  } catch (e) {
    _snack(messenger, 'Could not update favorite: $e');
  }
}

/// "Play next": the song plays right after the current one. [PRD FR-008]
Future<void> playNextWithMessage(
  BuildContext context,
  WidgetRef ref,
  Song song,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final handler = ref.read(audioHandlerProvider);
  try {
    final result = await handler.playSongNext(song);
    Haptics.light();
    _snack(messenger,
        queueAddMessage(result, playNext: true, title: song.title));
  } catch (e) {
    _snack(messenger, 'Could not change the queue: $e');
  }
}

/// "Add to queue": the song goes to the end of the queue. [PRD FR-008]
Future<void> addToQueueWithMessage(
  BuildContext context,
  WidgetRef ref,
  Song song,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final handler = ref.read(audioHandlerProvider);
  try {
    final result = await handler.addSongToQueue(song);
    Haptics.light();
    _snack(messenger,
        queueAddMessage(result, playNext: false, title: song.title));
  } catch (e) {
    _snack(messenger, 'Could not change the queue: $e');
  }
}

/// Asks first, then removes. [PRD FR-006]
/// Shared by every song list (Songs, Favorites, albums, ...).
Future<void> confirmAndRemoveSong(
  BuildContext context,
  WidgetRef ref,
  Song song,
) async {
  // Grab everything we need BEFORE the first await: the list that owns this
  // row can change while the dialog or the removal is running.
  final messenger = ScaffoldMessenger.of(context);
  final handler = ref.read(audioHandlerProvider);
  final library = ref.read(songsProvider.notifier);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remove song?'),
      content: Text(
        '"${song.title}" will be removed from your library. Its imported '
        'copy and any saved loop settings will be deleted.\n\n'
        'Your original file in the Files app is not affected.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  Haptics.medium(); // a removal the user just confirmed

  try {
    // Stop playing it first: never delete a file that is being played.
    await handler.removeFromQueue(song.id);
    await library.removeSong(song);
    _snack(messenger, 'Removed "${song.title}".');
  } catch (e) {
    _snack(messenger, 'Could not remove the song: $e');
  }
}
