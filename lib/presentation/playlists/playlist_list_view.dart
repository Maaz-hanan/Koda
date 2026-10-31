import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
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

  // Bigger rows than the song rows: a 72 pt cover, full width, and the
  // divider starts exactly where the text starts (20 + 72 + 16 gap).
  static const double _art = 72;
  static const double _gap = 16;
  static const _separator = Divider(
    height: 0.5,
    thickness: 0.5,
    indent: AppSpacing.pageMargin + _art + _gap,
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
          minTileHeight: 88,
          minVerticalPadding: 8,
          horizontalTitleGap: _gap,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin),
          leading: Container(
            width: _art,
            height: _art,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add, size: 32, color: AppColors.accent),
          ),
          title: const Text(
            'New playlist',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.accent),
          ),
          onTap: () {
            Haptics.tick();
            createPlaylistWithPrompt(context, ref);
          },
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
            minTileHeight: 88,
            minVerticalPadding: 8,
            horizontalTitleGap: _gap,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageMargin),
            leading: ArtworkWidget(
              path: _artworkFor(p.id),
              size: _art,
              radius: 10,
            ),
            title: Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(songCountText(library.countOf(p.id))),
            trailing:
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            onTap: () {
              Haptics.tick();
              PlaylistDetailScreen.open(context, p.id);
            },
          ),
          _separator,
        ],
      ],
    );
  }
}
