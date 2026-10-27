import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/playlist.dart';
import '../../domain/library/playlist_rules.dart';
import 'playlist_actions.dart';
import 'playlist_detail_screen.dart';

/// The Playlists tab: "New playlist" on top, then one row per playlist.
/// [PRD FR-003]
class PlaylistListView extends ConsumerWidget {
  const PlaylistListView({
    super.key,
    required this.library,
    required this.playlists,
    required this.hasQuery,
  });

  /// Source of the song counts.
  final PlaylistLibrary library;

  /// The playlists to show (already filtered by the search box).
  final List<Playlist> playlists;

  final bool hasQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.add, color: scheme.onPrimaryContainer),
          ),
          title: const Text('New playlist'),
          onTap: () => createPlaylistWithPrompt(context, ref),
        ),
        const Divider(height: 1),
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              hasQuery
                  ? 'No playlists match your search.'
                  : 'No playlists yet.\nCreate one to group your songs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final p in playlists) ...[
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.queue_music, color: scheme.onSurfaceVariant),
            ),
            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(songCountText(library.countOf(p.id))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => PlaylistDetailScreen.open(context, p.id),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}
