import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/models/song.dart';
import 'package:loop_player/presentation/library/list_message.dart';
import 'package:loop_player/presentation/library/song_list_view.dart';
import 'package:loop_player/presentation/shared/empty_state.dart';
import 'package:loop_player/presentation/shared/equalizer_icon.dart';
import 'package:loop_player/presentation/shared/favorite_button.dart';
import 'package:loop_player/presentation/theme/app_theme.dart';

Widget _host(Widget child) => MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: child),
    );

const _song = Song(
  id: 'a',
  title: 'Earrings',
  artist: 'Malcolm Todd',
  durationMs: 185000,
  filePath: 'music/a.mp3',
  importedAt: 0,
);

SongTile _tile({
  Song song = _song,
  bool isCurrent = false,
  bool isPlaying = false,
  VoidCallback? onTap,
  VoidCallback? onRemove,
  ValueChanged<bool>? onFavoriteChanged,
  VoidCallback? onPlayNext,
  VoidCallback? onAddToQueue,
  VoidCallback? onAddToPlaylist,
  String removeLabel = 'Remove from library',
  bool longPressRemoves = true,
}) =>
    SongTile(
      song: song,
      isCurrent: isCurrent,
      isPlaying: isPlaying,
      onTap: onTap ?? () {},
      onRemove: onRemove ?? () {},
      onFavoriteChanged: onFavoriteChanged ?? (_) {},
      onPlayNext: onPlayNext,
      onAddToQueue: onAddToQueue,
      onAddToPlaylist: onAddToPlaylist,
      removeLabel: removeLabel,
      longPressRemoves: longPressRemoves,
    );

void main() {
  group('SongTile', () {
    testWidgets('shows title, artist and duration in a 64 pt row',
        (tester) async {
      await tester.pumpWidget(_host(_tile()));
      expect(find.text('Earrings'), findsOneWidget);
      expect(find.text('Malcolm Todd'), findsOneWidget);
      expect(find.text('3:05'), findsOneWidget);
      expect(find.byTooltip('Add to favorites'), findsOneWidget);
      expect(find.byTooltip('More options'), findsOneWidget);
      expect(tester.getSize(find.byType(ListTile)).height, 64);
    });

    testWidgets('an unknown duration shows --:--', (tester) async {
      await tester.pumpWidget(_host(_tile(song: _song.copyWith(durationMs: 0))));
      expect(find.text('--:--'), findsOneWidget);
    });

    testWidgets('a normal song has a plain title and no bars', (tester) async {
      await tester.pumpWidget(_host(_tile()));
      expect(find.byType(EqualizerIcon), findsNothing);
      expect(tester.widget<Text>(find.text('Earrings')).style?.color, isNull);
    });

    testWidgets('the current song has an accent title and bars over its art',
        (tester) async {
      await tester.pumpWidget(_host(_tile(isCurrent: true)));
      await tester.pumpAndSettle();
      expect(find.byType(EqualizerIcon), findsOneWidget);
      expect(tester.widget<Text>(find.text('Earrings')).style?.color,
          AppColors.accent);
    });

    testWidgets('the bars move while playing and rest when paused',
        (tester) async {
      await tester.pumpWidget(_host(_tile(isCurrent: true, isPlaying: true)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(_host(_tile(isCurrent: true, isPlaying: false)));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('tapping the row calls onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(_tile(onTap: () => taps++)));
      await tester.tap(find.text('Earrings'));
      expect(taps, 1);
    });

    testWidgets('long press removes only when allowed', (tester) async {
      var removes = 0;
      await tester.pumpWidget(_host(_tile(onRemove: () => removes++)));
      await tester.longPress(find.text('Earrings'));
      expect(removes, 1);

      await tester.pumpWidget(_host(
          _tile(onRemove: () => removes++, longPressRemoves: false)));
      await tester.longPress(find.text('Earrings'));
      expect(removes, 1);
    });

    testWidgets('the heart reports the new value', (tester) async {
      bool? value;
      await tester.pumpWidget(_host(_tile(onFavoriteChanged: (v) => value = v)));
      await tester.tap(find.byTooltip('Add to favorites'));
      expect(value, isTrue);

      await tester.pumpWidget(_host(_tile(
        song: _song.copyWith(isFavorite: true),
        onFavoriteChanged: (v) => value = v,
      )));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      await tester.tap(find.byTooltip('Remove from favorites'));
      expect(value, isFalse);
    });

    testWidgets('the menu lists every action and calls the right one',
        (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_host(_tile(
        onPlayNext: () => calls.add('next'),
        onAddToQueue: () => calls.add('queue'),
        onAddToPlaylist: () => calls.add('playlist'),
        onRemove: () => calls.add('remove'),
      )));

      Future<void> choose(String label) async {
        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      expect(find.text('Play next'), findsOneWidget);
      expect(find.text('Add to queue'), findsOneWidget);
      expect(find.text('Add to playlist...'), findsOneWidget);
      expect(find.text('Remove from library'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5)); // close the menu
      await tester.pumpAndSettle();

      await choose('Play next');
      await choose('Add to queue');
      await choose('Add to playlist...');
      await choose('Remove from library');
      expect(calls, ['next', 'queue', 'playlist', 'remove']);
    });

    testWidgets('a playlist row says "Remove from playlist"', (tester) async {
      await tester.pumpWidget(
          _host(_tile(removeLabel: 'Remove from playlist')));
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      expect(find.text('Remove from playlist'), findsOneWidget);
      expect(find.text('Remove from library'), findsNothing);
      // No optional actions were given, so they are not offered.
      expect(find.text('Play next'), findsNothing);
    });
  });

  group('FavoriteButton compact', () {
    testWidgets('is grey and small when off, red when on', (tester) async {
      await tester.pumpWidget(_host(
          FavoriteButton(isFavorite: false, compact: true, onChanged: (_) {})));
      final off = tester.widget<Icon>(find.byIcon(Icons.favorite_border));
      expect(off.color, AppColors.textTertiary);
      expect(tester.widget<IconButton>(find.byType(IconButton)).iconSize, 20);

      await tester.pumpWidget(_host(
          FavoriteButton(isFavorite: true, compact: true, onChanged: (_) {})));
      expect(tester.widget<Icon>(find.byIcon(Icons.favorite)).color,
          AppColors.favoriteOn);
    });
  });

  group('EmptyState', () {
    testWidgets('shows icon, title, message and a working button',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(EmptyState(
        icon: Icons.library_music_outlined,
        title: 'Your library is empty',
        message: 'Import some files.',
        actionLabel: 'Import music',
        onAction: () => taps++,
      )));

      expect(find.byIcon(Icons.library_music_outlined), findsOneWidget);
      expect(find.text('Your library is empty'), findsOneWidget);
      expect(find.text('Import some files.'), findsOneWidget);
      await tester.tap(find.text('Import music'));
      expect(taps, 1);
    });

    testWidgets('has no button without an action', (tester) async {
      await tester.pumpWidget(_host(const EmptyState(
        icon: Icons.history,
        title: 'Nothing yet',
      )));
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('ListMessage', () {
    testWidgets('two lines = bold title + explanation', (tester) async {
      await tester.pumpWidget(_host(const ListMessage(
          'No favorites yet.\nTap the heart on a song to add it.',
          icon: Icons.favorite_border)));

      expect(find.text('No favorites yet.'), findsOneWidget);
      expect(find.text('Tap the heart on a song to add it.'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(tester.widget<Text>(find.text('No favorites yet.')).style?.fontSize,
          20);
    });

    testWidgets('one line = plain secondary text, no icon needed',
        (tester) async {
      await tester.pumpWidget(_host(const ListMessage('No songs match "x".')));
      expect(find.text('No songs match "x".'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(tester.widget<Text>(find.text('No songs match "x".')).style?.fontSize,
          17);
    });
  });
}
