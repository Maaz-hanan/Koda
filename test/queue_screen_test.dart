import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/presentation/queue/queue_screen.dart';
import 'package:loop_player/providers/audio_handler_provider.dart';

MediaItem _item(String id, String title, {String? artist}) =>
    MediaItem(id: id, title: title, artist: artist);

Widget _host(List<MediaItem> queue, String? currentId) => ProviderScope(
      overrides: [
        queueProvider.overrideWith((ref) => Stream.value(queue)),
        currentMediaItemProvider.overrideWith(
          (ref) => Stream.value(
            currentId == null
                ? null
                : queue.firstWhere((m) => m.id == currentId),
          ),
        ),
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
    await tester.pumpWidget(_host(queue, 'b'));
    await tester.pumpAndSettle();

    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('First Song'), findsOneWidget);
    expect(find.text('Second Song'), findsOneWidget);
    expect(find.text('Third Song'), findsOneWidget);
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Unknown Artist'), findsOneWidget); // Second Song
  });

  testWidgets('the playing song is marked and has no remove button',
      (tester) async {
    await tester.pumpWidget(_host(queue, 'b'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    // 3 songs, the playing one has no X -> 2 remove buttons.
    expect(find.byTooltip('Remove from queue'), findsNWidgets(2));
  });

  testWidgets('an empty queue shows a message', (tester) async {
    await tester.pumpWidget(_host(const [], null));
    await tester.pumpAndSettle();

    expect(find.textContaining('The queue is empty'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });
}
