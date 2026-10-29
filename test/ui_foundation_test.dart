import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/presentation/now_playing/shuffle_button.dart';
import 'package:loop_player/presentation/shared/circle_icon_button.dart';
import 'package:loop_player/presentation/shared/glass_container.dart';
import 'package:loop_player/presentation/shared/shuffle_play_button.dart';
import 'package:loop_player/presentation/theme/app_theme.dart';

Widget _host(Widget child) => MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('buildAppTheme', () {
    final theme = buildAppTheme();

    test('is dark, black and accent red', () {
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.accent);
      expect(theme.colorScheme.onSurface, AppColors.textPrimary);
      expect(theme.useMaterial3, isTrue);
    });

    test('text sizes follow the design profile', () {
      expect(theme.textTheme.headlineLarge?.fontSize, 34);
      expect(theme.textTheme.titleLarge?.fontSize, 22);
      expect(theme.textTheme.titleMedium?.fontSize, 17);
      expect(theme.textTheme.bodyMedium?.fontSize, 15);
    });

    test('dialogs, sheets and the app bar are styled', () {
      expect(theme.dialogTheme.backgroundColor, AppColors.surfaceRaised);
      expect(theme.bottomSheetTheme.backgroundColor, AppColors.surface);
      expect(theme.appBarTheme.backgroundColor, AppColors.background);
      expect(theme.appBarTheme.elevation, 0);
    });

    test('the tonal button color comes from the scheme, not the accent', () {
      expect(theme.colorScheme.secondaryContainer, AppColors.surfaceRaised);
    });
  });

  testWidgets('the whole app theme builds a normal screen', (tester) async {
    await tester.pumpWidget(_host(const Text('Hello')));
    expect(find.text('Hello'), findsOneWidget);
  });

  group('GlassContainer', () {
    testWidgets('shows its child inside a blur', (tester) async {
      await tester.pumpWidget(_host(const GlassContainer(
        child: SizedBox(width: 80, height: 40, child: Text('Glass')),
      )));
      expect(find.text('Glass'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('can add padding and a shadow', (tester) async {
      await tester.pumpWidget(_host(const GlassContainer(
        padding: EdgeInsets.all(10),
        shadow: true,
        child: SizedBox(width: 60, height: 20),
      )));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GlassContainer)), const Size(80, 40));
    });
  });

  group('CircleIconButton', () {
    testWidgets('is a 44 x 44 circle and taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(CircleIconButton(
        icon: Icons.favorite,
        tooltip: 'Heart',
        onPressed: () => taps++,
      )));

      expect(tester.getSize(find.byType(CircleIconButton)), const Size(44, 44));
      expect(find.byTooltip('Heart'), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      expect(taps, 1);
    });

    testWidgets('white when off, accent when active', (tester) async {
      await tester.pumpWidget(_host(CircleIconButton(
        icon: Icons.shuffle,
        onPressed: () {},
      )));
      expect(tester.widget<Icon>(find.byIcon(Icons.shuffle)).color,
          AppColors.textPrimary);

      await tester.pumpWidget(_host(CircleIconButton(
        icon: Icons.shuffle,
        active: true,
        onPressed: () {},
      )));
      expect(tester.widget<Icon>(find.byIcon(Icons.shuffle)).color,
          AppColors.accent);
    });

    testWidgets('greyed out and not tappable without onPressed',
        (tester) async {
      await tester.pumpWidget(_host(const CircleIconButton(
        icon: Icons.shuffle,
        onPressed: null,
      )));
      expect(tester.widget<Icon>(find.byIcon(Icons.shuffle)).color,
          AppColors.textTertiary);
      expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNull);
    });
  });

  group('shuffle buttons', () {
    testWidgets('ShuffleButton shows on / off and taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
          _host(ShuffleButton(isOn: false, onPressed: () => taps++)));
      expect(find.byTooltip('Shuffle: off'), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      expect(taps, 1);

      await tester.pumpWidget(
          _host(ShuffleButton(isOn: true, onPressed: () => taps++)));
      expect(find.byTooltip('Shuffle: on'), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Icons.shuffle)).color,
          AppColors.accent);
    });

    testWidgets('ShufflePlayButton shows its label and taps', (tester) async {
      var taps = 0;
      await tester
          .pumpWidget(_host(ShufflePlayButton(onPressed: () => taps++)));
      expect(find.text('Shuffle'), findsOneWidget);
      await tester.tap(find.text('Shuffle'));
      expect(taps, 1);
    });

    testWidgets('ShufflePlayButton is disabled without onPressed',
        (tester) async {
      await tester
          .pumpWidget(_host(const ShufflePlayButton(onPressed: null)));
      final button = tester.widget<ButtonStyleButton>(
          find.byWidgetPredicate((w) => w is ButtonStyleButton));
      expect(button.onPressed, isNull);
    });
  });
}
