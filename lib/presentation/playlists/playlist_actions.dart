import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../domain/library/playlist_rules.dart';
import '../../providers/playlist_provider.dart';
import 'playlist_dialogs.dart';

void _snack(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

List<String> _names(WidgetRef ref, {String? except}) =>
    ref.read(playlistsProvider).maybeWhen<List<String>>(
          data: (lib) => [
            for (final p in lib.playlists)
              if (p.name != except) p.name,
          ],
          orElse: () => const [],
        );

/// Asks for a name and creates the playlist. Returns it, or null if the user
/// cancelled or saving failed.
Future<Playlist?> createPlaylistWithPrompt(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(playlistsProvider.notifier);
  final name = await promptPlaylistName(
    context,
    title: 'New playlist',
    confirmLabel: 'Create',
    existingNames: _names(ref),
  );
  if (name == null) return null;
  try {
    return await notifier.create(name);
  } catch (e) {
    _snack(messenger, 'Could not create the playlist: $e');
    return null;
  }
}

Future<void> renamePlaylistWithPrompt(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(playlistsProvider.notifier);
  final name = await promptPlaylistName(
    context,
    title: 'Rename playlist',
    confirmLabel: 'Rename',
    initial: playlist.name,
    existingNames: _names(ref, except: playlist.name),
  );
  if (name == null || name == playlist.name) return;
  try {
    await notifier.rename(playlist.id, name);
  } catch (e) {
    _snack(messenger, 'Could not rename the playlist: $e');
  }
}

/// Asks first, deletes, then closes the playlist screen.
Future<void> deletePlaylistWithConfirm(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final notifier = ref.read(playlistsProvider.notifier);
  if (!await confirmDeletePlaylist(context, playlist.name)) return;
  try {
    await notifier.delete(playlist.id);
    navigator.pop();
    _snack(messenger, 'Deleted "${playlist.name}".');
  } catch (e) {
    _snack(messenger, 'Could not delete the playlist: $e');
  }
}

/// Takes a song out of ONE playlist (it stays in the library).
Future<void> removeSongFromPlaylist(
  BuildContext context,
  WidgetRef ref,
  String playlistId,
  Song song,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(playlistsProvider.notifier);
  try {
    await notifier.removeSong(playlistId, song.id);
    _snack(messenger, 'Removed "${song.title}" from the playlist.');
  } catch (e) {
    _snack(messenger, 'Could not remove the song: $e');
  }
}

/// "Add to playlist": a sheet listing the playlists, plus "New playlist".
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  Song song,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _AddToPlaylistSheet(song: song),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  const _AddToPlaylistSheet({required this.song});

  final Song song;

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notifier = ref.read(playlistsProvider.notifier);
    try {
      final added = await notifier.addSong(playlist.id, song.id);
      navigator.pop();
      _snack(
        messenger,
        added
            ? 'Added to "${playlist.name}".'
            : 'Already in "${playlist.name}".',
      );
    } catch (e) {
      navigator.pop();
      _snack(messenger, 'Could not add the song: $e');
    }
  }

  Future<void> _addToNew(BuildContext context, WidgetRef ref) async {
    final created = await createPlaylistWithPrompt(context, ref);
    if (created == null || !context.mounted) return;
    await _add(context, ref, created);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(playlistsProvider).maybeWhen<PlaylistLibrary>(
          data: (v) => v,
          orElse: () => const PlaylistLibrary.empty(),
        );
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New playlist'),
              onTap: () => _addToNew(context, ref),
            ),
            for (final p in library.playlists)
              ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(songCountText(library.countOf(p.id))),
                onTap: () => _add(context, ref, p),
              ),
          ],
        ),
      ),
    );
  }
}
