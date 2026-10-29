import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/presentation/shared/glass_container.dart';
import 'package:loop_player/presentation/shared/mini_player.dart';
import 'package:loop_player/presentation/theme/app_theme.dart';
import 'package:loop_player/providers/audio_handler_provider.dart';

Widget _host({
  MediaItem? item,
  bool playing = false,
  Widget? body,
}) =>
    ProviderScope(
      overrides: [
        currentMediaItemProvider.overrideWith((ref) => Stream.value(item)),
        playbackStateProvider.overrideWith(
            (ref) => Stream.value(PlaybackState(playing: playing))),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          extendBody: true,
          bottomNavigationBar: const MiniPlayer(),
          body: body ?? const SizedBox.expand(),
        ),
      ),
    );

const _song = MediaItem(id: 'a', title: 'Earrings', artist: 'Malcolm Todd');

void main() {
  testWidgets('draws nothing when no song is loaded', (tester) async {
    await tester.pumpWidget(_host(item: null));
    await tester.pumpAndSettle();

    expect(find.byType(GlassContainer), findsNothing);
    expect(find.text('Earrings'), findsNothing);
  });

  testWidgets('is a 60 pt floating glass pill with title and artist',
      (tester) async {
    await tester.pumpWidget(_host(item: _song));
    await tester.pumpAndSettle();

    expect(find.byType(GlassContainer), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Earrings'), findsOneWidget);
    expect(find.text('Malcolm Todd'), findsOneWidget);

    final size = tester.getSize(find.byType(GlassContainer));
    expect(size.height, MiniPlayer.height);
    // 12 pt margin on both sides of the screen.
    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(size.width, closeTo(screenWidth - 24, 0.01));
  });

  testWidgets('an unknown artist is shown as Unknown Artist', (tester) async {
    await tester.pumpWidget(
        _host(item: const MediaItem(id: 'b', title: 'No Artist')));
    await tester.pumpAndSettle();
    expect(find.text('Unknown Artist'), findsOneWidget);
  });

  testWidgets('shows Play and Next while paused', (tester) async {
    await tester.pumpWidget(_host(item: _song, playing: false));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byTooltip('Next song'), findsOneWidget);
  });

  testWidgets('shows Pause while playing', (tester) async {
    await tester.pumpWidget(_host(item: _song, playing: true));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('a list under it can scroll its last row clear of the pill',
      (tester) async {
    await tester.pumpWidget(_host(
      item: _song,
      body: ListView(
        children: [
          for (var i = 0; i < 40; i++)
            SizedBox(height: 64, child: Text('Row $i')),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -10000));
    await tester.pumpAndSettle();

    final lastRowBottom = tester.getBottomLeft(find.text('Row 39')).dy;
    final pillTop = tester.getTopLeft(find.byType(GlassContainer)).dy;
    expect(lastRowBottom, lessThanOrEqualTo(pillTop));
  });

  testWidgets('without a song the list uses the whole height', (tester) async {
    await tester.pumpWidget(_host(
      item: null,
      body: ListView(
        children: [
          for (var i = 0; i < 40; i++)
            SizedBox(height: 64, child: Text('Row $i')),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -10000));
    await tester.pumpAndSettle();

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final lastRowBottom = tester.getBottomLeft(find.text('Row 39')).dy;
    expect(lastRowBottom, closeTo(screenHeight, 0.5));
  });
}
