import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/models/song.dart';
import 'package:loop_player/presentation/shared/favorite_button.dart';

void main() {
  Widget host(bool isFavorite, ValueChanged<bool> onChanged) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: FavoriteButton(isFavorite: isFavorite, onChanged: onChanged),
          ),
        ),
      );

  testWidgets('not a favorite: outline heart, tapping asks to ADD',
      (tester) async {
    bool? result;
    await tester.pumpWidget(host(false, (v) => result = v));
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byTooltip('Add to favorites'), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    expect(result, isTrue);
  });

  testWidgets('favorite: filled heart, tapping asks to REMOVE',
      (tester) async {
    bool? result;
    await tester.pumpWidget(host(true, (v) => result = v));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    expect(result, isFalse);
  });

  group('Song favorite / last played fields', () {
    const base = Song(
      id: 'a',
      title: 'T',
      durationMs: 1000,
      filePath: 'music/a.mp3',
      importedAt: 5,
    );

    test('default: not a favorite, never played', () {
      expect(base.isFavorite, isFalse);
      expect(base.lastPlayedAt, isNull);
    });

    test('survive a save / load round trip', () {
      final song = base.copyWith(isFavorite: true, lastPlayedAt: 12345);
      final back = Song.fromMap(song.toMap());
      expect(back.isFavorite, isTrue);
      expect(back.lastPlayedAt, 12345);
    });

    test('copyWith changes only what it is told to', () {
      final song = base.copyWith(lastPlayedAt: 99).copyWith(isFavorite: true);
      expect(song.lastPlayedAt, 99);
      expect(song.isFavorite, isTrue);
      expect(song.title, 'T');
    });
  });
}
