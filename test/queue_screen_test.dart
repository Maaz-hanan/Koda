import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/models/song.dart';
import 'package:loop_player/domain/loop/loop_mode.dart';
import 'package:loop_player/presentation/queue/queue_screen.dart';
import 'package:loop_player/presentation/shared/equalizer_icon.dart';
import 'package:loop_player/providers/audio_handler_provider.dart';
import 'package:loop_player/providers/library_provider.dart';

class _FakeLibrary extends LibraryNotifier {
  @override
  Future<List<Song>> build() async => [];
}

class _FakeShuffle extends ShuffleNotifier {
  @override
  bool build() => false;
}

class _FakeRepeat extends RepeatModeNotifier {
  @override
  LoopMode build() => LoopMode.off;
}

MediaItem _item(String id, String title, {String? artist}) =>
    MediaItem(id: id, title: title, artist: artist);

Widget _host(List<MediaItem> queue, String? currentId, {bool playing = true}) =>
    ProviderScope(
      overrides: [
        songsProvider.overrideWith(_FakeLibrary.new),
        shuffleProvider.overrideWith(_FakeShuffle.new),
        repeatModeProvider.overrideWith(_FakeRepeat.new),
        queueProvider.overrideWith((ref) => Stream.value(queue)),
        currentMediaItemProvider.overrideWith(
          (ref) => Stream.value(
            currentId == null
                ? null
                : queue.firstWhere((m) => m.id == currentId),
          ),
        ),
        playbackStateProvider
            .overrideWith((ref) => Stream.value(PlaybackState(playing: playing))),
      ],
      child: const MaterialApp(home: QueueScreen()),
    );

void main() {
  final queue = [
    _item('a', 'First Song', artist: 'Ann'),
    _item('b', 'Second Song'),
    _item('c', 'Third Song', artist: 'Cy'),
  ];

  testWidgets('lists every song with its artist', (tester) async {
    await tester.pumpWidget(_host(queue, 'b', playing: false));
    await tester.pumpAndSettle();

    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('First Song'), findsOneWidget);
    // The playing song is also shown in the header above the list.
    expect(find.text('Second Song'), findsNWidgets(2));
    expect(find.text('Third Song'), findsOneWidget);
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Unknown Artist'), findsNWidgets(2)); // Second Song
    expect(find.text('Up Next'), findsOneWidget);
  });

  testWidgets('the pill row has Shuffle, Loop, Edit loop, Add to playlist',
      (tester) async {
    await tester.pumpWidget(_host(queue, 'b', playing: false));
    await tester.pumpAndSettle();
    for (final label in ['Shuffle', 'Loop', 'Edit loop', 'Add to playlist']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('the playing song is marked and has no remove button',
      (tester) async {
    await tester.pumpWidget(_host(queue, 'b', playing: false));
    await tester.pumpAndSettle();

    expect(find.byType(EqualizerIcon), findsOneWidget);
    // 3 songs, the playing one has no X -> 2 remove buttons.
    expect(find.byTooltip('Remove from queue'), findsNWidgets(2));
  });

  testWidgets('the bars and the X buttons are aligned in one column',
      (tester) async {
    await tester.pumpWidget(_host(queue, 'b', playing: false));
    await tester.pumpAndSettle();

    final barsX = tester.getCenter(find.byType(EqualizerIcon)).dx;
    final xButtons = find.byIcon(Icons.close);
    expect(xButtons, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      expect(tester.getCenter(xButtons.at(i)).dx, closeTo(barsX, 0.01));
    }
  });

  testWidgets('the bars move while playing', (tester) async {
    await tester.pumpWidget(_host(queue, 'b', playing: true));
    await tester.pump(); // let the stream deliver
    await tester.pump(const Duration(milliseconds: 100));
    // A repeating animation never "settles": proof that the bars are alive.
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('the bars rest while paused', (tester) async {
    await tester.pumpWidget(_host(queue, 'b', playing: false));
    await tester.pumpAndSettle(); // would time out if something kept moving
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('an empty queue shows a message', (tester) async {
    await tester.pumpWidget(_host(const [], null, playing: false));
    await tester.pumpAndSettle();

    expect(find.textContaining('The queue is empty'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });
}
