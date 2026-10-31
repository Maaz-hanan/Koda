import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/models/song.dart';
import 'package:loop_player/presentation/library/edit_song_sheet.dart';

const _song = Song(
  id: 'a',
  title: 'Old Title',
  durationMs: 1000,
  filePath: 'music/a.mp3',
  importedAt: 0,
);

Widget _host({Future<String?> Function()? pick}) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: EditSongSheet(
            song: _song,
            pickCover: pick ?? () async => null,
          ),
        ),
      ),
    );

bool _saveEnabled(WidgetTester tester) => tester
    .widget<FilledButton>(find.byKey(const Key('edit_song_save_button')))
    .enabled;

void main() {
  testWidgets('starts with the current title and Save disabled',
      (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('Old Title'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('a changed title enables Save, an empty one disables it',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.enterText(
        find.byKey(const Key('edit_song_title_field')), 'New Title');
    await tester.pump();
    expect(_saveEnabled(tester), isTrue);

    await tester.enterText(find.byKey(const Key('edit_song_title_field')), '   ');
    await tester.pump();
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('the same title with extra spaces is not a change',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.enterText(
        find.byKey(const Key('edit_song_title_field')), '  Old   Title ');
    await tester.pump();
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('typing an artist enables Save; an empty artist does not',
      (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byKey(const Key('edit_song_artist_field')), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('edit_song_artist_field')), '  Malcolm  Todd ');
    await tester.pump();
    expect(_saveEnabled(tester), isTrue);

    await tester.enterText(find.byKey(const Key('edit_song_artist_field')), '  ');
    await tester.pump();
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('choosing a cover enables Save', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_host(pick: () async {
      calls++;
      return '/no/such/picture.jpg';
    }));
    await tester.tap(find.byKey(const Key('edit_song_cover_button')));
    await tester.pump();
    await tester.pump();
    expect(calls, 1);
    expect(_saveEnabled(tester), isTrue);
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    await tester.pumpWidget(_host(pick: () async => null));
    await tester.tap(find.byKey(const Key('edit_song_cover_button')));
    await tester.pump();
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('a picker error shows a message', (tester) async {
    await tester.pumpWidget(_host(pick: () async => throw Exception('x')));
    await tester.tap(find.byKey(const Key('edit_song_cover_button')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Could not open your photos.'), findsOneWidget);
  });
}
