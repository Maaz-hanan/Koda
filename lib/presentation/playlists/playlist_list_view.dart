import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage_paths.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../domain/library/playlist_rules.dart';
import '../shared/artwork_widget.dart';
import '../theme/app_theme.dart';
import 'playlist_actions.dart';
import 'playlist_detail_screen.dart';

/// The Playlists tab: "New playlist" on top, then one row per playlist with
/// the artwork of its first song. [PRD FR-003]
class PlaylistListView extends ConsumerWidget {
  const PlaylistListView({
    super.key,
    required this.library,
    required this.playlists,
    required this.hasQuery,
    this.allSongs = const [],
  });

  /// Source of the song counts.
  final PlaylistLibrary library;

  /// The playlists to show (already filtered by the search box).
  final List<Playlist> playlists;

  final bool hasQuery;

  /// All songs of the library: used to find each playlist's first artwork.
  final List<Song> allSongs;

  static const _separator = Divider(
    height: 0.5,
    thickness: 0.5,
    indent: AppSpacing.listTextInset,
  );

  /// The artwork of the first song of [playlistId] that has one, or null.
  String? _artworkFor(String playlistId) {
    for (final song in songsForIds(library.idsOf(playlistId), allSongs)) {
      if (song.artworkPath != null) return song.absoluteArtworkPath;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        ListTile(
          minTileHeight: 56,
          minVerticalPadding: 4,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin),
          leading: Container(
            width: AppSpacing.rowArtwork,
            height: AppSpacing.rowArtwork,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.rowArtwork),
            ),
            child: const Icon(Icons.add, color: AppColors.accent),
          ),
          title: const Text(
            'New playlist',
            style: TextStyle(color: AppColors.accent),
          ),
          onTap: () => createPlaylistWithPrompt(context, ref),
        ),
        _separator,
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              hasQuery
                  ? 'No playlists match your search.'
                  : 'No playlists yet.\nCreate one to group your songs.',
              textAlign: TextAlign.center,
              style: AppText.rowSubtitle,
            ),
          ),
        for (final p in playlists) ...[
          ListTile(
            minTileHeight: 56,
            minVerticalPadding: 4,
            contentPadding: const EdgeInsets.only(
                left: AppSpacing.pageMargin, right: 12),
            leading: ArtworkWidget(
              path: _artworkFor(p.id),
              size: AppSpacing.rowArtwork,
              radius: AppRadius.rowArtwork,
            ),
            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(songCountText(library.countOf(p.id))),
            trailing:
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            onTap: () => PlaylistDetailScreen.open(context, p.id),
          ),
          _separator,
        ],
      ],
    );
  }
}
