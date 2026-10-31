import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/presentation/library/library_bottom_bar.dart';
import 'package:loop_player/presentation/shared/mini_player.dart';
import 'package:loop_player/presentation/theme/app_theme.dart';
import 'package:loop_player/providers/audio_handler_provider.dart';
import 'package:loop_player/providers/search_provider.dart';

const _song = MediaItem(id: 'a', title: 'Earrings', artist: 'Malcolm Todd');

/// Gives the bar a real TabController and exposes the collapse switch.
class _Host extends StatefulWidget {
  const _Host({required this.collapsed, required this.onController});

  final ValueNotifier<bool> collapsed;
  final void Function(TabController) onController;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 4, vsync: this);
    widget.onController(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: const SizedBox.expand(),
      bottomNavigationBar:
          LibraryBottomBar(controller: _controller, collapsed: widget.collapsed),
    );
  }
}

Widget _app(
  ValueNotifier<bool> collapsed,
  void Function(TabController) onController, {
  MediaItem? item,
}) =>
    ProviderScope(
      overrides: [
        currentMediaItemProvider.overrideWith((ref) => Stream.value(item)),
        playbackStateProvider.overrideWith(
            (ref) => Stream.value(PlaybackState(playing: false))),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: _Host(collapsed: collapsed, onController: onController),
      ),
    );

void main() {
  late ValueNotifier<bool> collapsed;
  late TabController controller;

  setUp(() => collapsed = ValueNotifier<bool>(false));
  tearDown(() => collapsed.dispose());

  Future<void> pump(WidgetTester tester, {MediaItem? item}) async {
    await tester.pumpWidget(_app(collapsed, (c) => controller = c, item: item));
    await tester.pumpAndSettle();
  }

  testWidgets('open: four tabs with icons and a search button',
      (tester) async {
    await pump(tester);
    for (final label in ['Songs', 'Playlists', 'Favorites', 'Recents']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byIcon(Icons.music_note), findsOneWidget);
    expect(find.byIcon(Icons.queue_music), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.byKey(const Key('library_search_button')), findsOneWidget);
  });

  testWidgets('tapping a tab moves the pages', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('library_tab_2')));
    await tester.pumpAndSettle();
    expect(controller.index, 2);
  });

  testWidgets('open: the mini player sits above the tabs', (tester) async {
    await pump(tester, item: _song);
    final player = tester.getTopLeft(find.byType(MiniPlayer)).dy;
    final tabs = tester.getTopLeft(find.byKey(const Key('library_tab_0'))).dy;
    expect(player, lessThan(tabs));
    expect(find.byTooltip('Next song'), findsOneWidget);
  });

  testWidgets('collapsed: one row, tab icon | mini player | search',
      (tester) async {
    await pump(tester, item: _song);
    collapsed.value = true;
    await tester.pumpAndSettle();

    expect(find.text('Playlists'), findsNothing); // no tab labels
    final tabsButton = find.byKey(const Key('library_tabs_button'));
    final search = find.byKey(const Key('library_search_button'));
    expect(tabsButton, findsOneWidget);

    final left = tester.getCenter(tabsButton);
    final middle = tester.getCenter(find.byType(MiniPlayer));
    final right = tester.getCenter(search);
    expect(left.dx, lessThan(middle.dx));
    expect(middle.dx, lessThan(right.dx));
    expect((left.dy - middle.dy).abs(), lessThan(1)); // same row
    expect((right.dy - middle.dy).abs(), lessThan(1));
    expect(find.byTooltip('Next song'), findsNothing); // skip hidden
  });

  testWidgets('collapsed: the round tab icon shows the selected tab and '
      'opens the tabs again', (tester) async {
    await pump(tester);
    controller.index = 1; // Playlists
    collapsed.value = true;
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.queue_music), findsOneWidget);

    await tester.tap(find.byKey(const Key('library_tabs_button')));
    await tester.pumpAndSettle();
    expect(collapsed.value, isFalse);
    expect(find.text('Songs'), findsOneWidget);
  });

  testWidgets('search: opens a field, filters through the provider, and '
      'closing clears it', (tester) async {
    await pump(tester, item: _song);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(_Host)));

    await tester.tap(find.byKey(const Key('library_search_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library_search_field')), findsOneWidget);
    expect(find.text('Playlists'), findsNothing); // tabs replaced by the field
    // the mini player stays on top of the search field
    expect(tester.getTopLeft(find.byType(MiniPlayer)).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('library_search_field'))).dy));

    await tester.enterText(
        find.byKey(const Key('library_search_field')), 'earr');
    await tester.pump();
    expect(container.read(searchQueryProvider), 'earr');

    await tester.tap(find.byKey(const Key('library_close_search')));
    await tester.pumpAndSettle();
    expect(container.read(searchQueryProvider), '');
    expect(find.text('Playlists'), findsOneWidget);
  });
}
