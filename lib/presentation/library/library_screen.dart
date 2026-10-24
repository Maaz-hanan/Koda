import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage_paths.dart';
import '../../data/models/song.dart';
import '../../data/services/import_service.dart';
import '../../domain/library/song_search.dart';
import '../../providers/audio_handler_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/search_provider.dart';
import '../shared/artwork_widget.dart';
import '../shared/mini_player.dart';

/// Library: import, search, list, play, remove.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ImportService.supportedExtensions,
    );
    if (files.isEmpty) return; // user cancelled

    final notifier = ref.read(songsProvider.notifier);
    var imported = 0;
    final errors = <String>[];

    for (final f in files) {
      final path = f.path;
      if (path == null) {
        errors.add('Could not access "${f.name}".');
        continue;
      }
      try {
        await notifier.importFile(sourcePath: path, originalName: f.name);
        imported++;
      } on ImportException catch (e) {
        errors.add(e.message);
      }
    }

    if (!context.mounted) return;
    final buffer = StringBuffer();
    if (imported > 0) {
      buffer.write('Imported $imported song${imported == 1 ? '' : 's'}. ');
    }
    if (errors.isNotEmpty) buffer.write(errors.join(' '));
    _snack(context, buffer.toString().trim());
  }

  /// Asks first, then removes. [PRD FR-006]
  Future<void> _confirmAndRemove(
    BuildContext context,
    WidgetRef ref,
    Song song,
  ) async {
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

    try {
      // Stop playing it first: never delete a file that is being played.
      await ref.read(audioHandlerProvider).removeFromQueue(song.id);
      await ref.read(songsProvider.notifier).removeSong(song);
      if (context.mounted) _snack(context, 'Removed "${song.title}".');
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not remove the song: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(songsProvider);
    final query = ref.watch(searchQueryProvider);
    final currentId = ref.watch(currentMediaItemProvider).when<String?>(
          data: (m) => m?.id,
          loading: () => null,
          error: (e, s) => null,
        );

    // Show playback problems (e.g. a damaged file) as a message.
    ref.listen<AsyncValue<String>>(playbackErrorProvider, (previous, next) {
      next.whenData((message) => _snack(context, message));
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Import music',
            onPressed: () => _import(context, ref),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: songs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load your library.\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (all) {
          if (all.isEmpty) {
            return _EmptyState(onImport: () => _import(context, ref));
          }
          final shown = filterSongs(all, query);
          return Column(
            children: [
              const _SearchField(),
              Expanded(
                child: shown.isEmpty
                    ? _NoResults(query: query)
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: shown.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) => _SongTile(
                          song: shown[i],
                          isCurrent: shown[i].id == currentId,
                          onTap: () => ref
                              .read(audioHandlerProvider)
                              .playQueue(shown, i),
                          onRemove: () =>
                              _confirmAndRemove(context, ref, shown[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = ref.watch(searchQueryProvider).isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SearchBar(
        controller: _controller,
        hintText: 'Search songs, artists, albums',
        leading: const Icon(Icons.search),
        trailing: [
          if (hasText)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear search',
              onPressed: () {
                _controller.clear();
                ref.read(searchQueryProvider.notifier).set('');
              },
            ),
        ],
        onChanged: (value) => ref.read(searchQueryProvider.notifier).set(value),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No songs match "${query.trim()}".',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music_outlined,
                size: 72, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Your library is empty',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Import MP3, M4A, AAC or WAV files from the Files app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add),
              label: const Text('Import music'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.isCurrent,
    required this.onTap,
    required this.onRemove,
  });

  final Song song;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

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
      onLongPress: onRemove,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_formatDuration(song.durationMs)),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (_) => onRemove(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'remove', child: Text('Remove from library')),
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
