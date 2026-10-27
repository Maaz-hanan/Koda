import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/models/playlist.dart';
import 'package:loop_player/presentation/playlists/playlist_list_view.dart';

Widget _host(PlaylistLibrary lib, {bool hasQuery = false}) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: PlaylistListView(
            library: lib,
            playlists: lib.playlists,
            hasQuery: hasQuery,
          ),
        ),
      ),
    );

void main() {
  testWidgets('shows New playlist, each playlist and its song count',
      (tester) async {
    final lib = PlaylistLibrary(
      playlists: const [
        Playlist(id: '1', name: 'Gym', createdAt: 0),
        Playlist(id: '2', name: 'Road trip', createdAt: 0),
      ],
      songIds: const {
        '1': ['a', 'b', 'c'],
        '2': ['a'],
      },
    );
    await tester.pumpWidget(_host(lib));

    expect(find.text('New playlist'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('3 songs'), findsOneWidget);
    expect(find.text('Road trip'), findsOneWidget);
    expect(find.text('1 song'), findsOneWidget);
  });

  testWidgets('no playlists: invitation to create one', (tester) async {
    await tester.pumpWidget(_host(const PlaylistLibrary.empty()));

    expect(find.text('New playlist'), findsOneWidget);
    expect(find.textContaining('No playlists yet'), findsOneWidget);
  });

  testWidgets('a search with no match says so', (tester) async {
    await tester.pumpWidget(
        _host(const PlaylistLibrary.empty(), hasQuery: true));

    expect(find.textContaining('No playlists match'), findsOneWidget);
    expect(find.text('New playlist'), findsOneWidget);
  });
}
