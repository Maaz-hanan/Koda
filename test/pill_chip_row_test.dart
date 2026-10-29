import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/presentation/shared/pill_chip_row.dart';
import 'package:loop_player/presentation/theme/app_theme.dart';

const _labels = ['Songs', 'Playlists', 'Favorites', 'Recently Played'];

Widget _host(int selected, ValueChanged<int> onSelected, {double width = 300}) =>
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: PillChipRow(
              labels: _labels,
              selectedIndex: selected,
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    );

Color? _chipColor(WidgetTester tester, String label) {
  final box = tester.widget<AnimatedContainer>(find.ancestor(
    of: find.text(label),
    matching: find.byType(AnimatedContainer),
  ));
  return (box.decoration as BoxDecoration).color;
}

void main() {
  testWidgets('shows every label', (tester) async {
    await tester.pumpWidget(_host(0, (_) {}, width: 1200));
    await tester.pumpAndSettle();
    for (final label in _labels) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('the selected chip is light with black text, the rest are dim',
      (tester) async {
    await tester.pumpWidget(_host(1, (_) {}, width: 1200));
    await tester.pumpAndSettle();

    expect(_chipColor(tester, 'Playlists'), AppColors.chipSelected);
    expect(_chipColor(tester, 'Songs'), AppColors.chipUnselected);
    expect(_chipColor(tester, 'Favorites'), AppColors.chipUnselected);

    expect(tester.widget<Text>(find.text('Playlists')).style?.color,
        Colors.black);
    expect(tester.widget<Text>(find.text('Songs')).style?.color,
        AppColors.textPrimary);
  });

  testWidgets('chips are 34 pt tall', (tester) async {
    await tester.pumpWidget(_host(0, (_) {}, width: 1200));
    await tester.pumpAndSettle();
    final chip = find.ancestor(
      of: find.text('Songs'),
      matching: find.byType(AnimatedContainer),
    );
    expect(tester.getSize(chip).height, 34);
  });

  testWidgets('tapping a chip reports its index', (tester) async {
    int? tapped;
    await tester.pumpWidget(_host(0, (i) => tapped = i, width: 1200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Favorites'));
    expect(tapped, 2);
    await tester.tap(find.text('Songs'));
    expect(tapped, 0);
  });

  testWidgets('the row scrolls so the newly selected chip is visible',
      (tester) async {
    await tester.pumpWidget(_host(0, (_) {}));
    await tester.pumpAndSettle();
    // Before: the last chip is far outside the 300 pt wide row.
    expect(tester.getRect(find.text('Recently Played')).right,
        greaterThan(300));

    await tester.pumpWidget(_host(3, (_) {}));
    await tester.pump(); // the scroll starts after the frame
    await tester.pumpAndSettle();

    expect(tester.getRect(find.text('Recently Played')).right,
        lessThanOrEqualTo(300));
    expect(tester.getRect(find.text('Recently Played')).left, greaterThan(0));
  });
}
