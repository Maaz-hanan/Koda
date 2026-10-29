import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/presentation/shared/equalizer_icon.dart';

Widget _host(bool animating, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(child: EqualizerIcon(animating: animating)),
        ),
      ),
    );

void main() {
  group('equalizerBarHeights', () {
    test('always between 0.2 and 1.0, for every moment', () {
      for (var i = 0; i <= 200; i++) {
        for (final h in equalizerBarHeights(i / 200)) {
          expect(h, inInclusiveRange(0.2, 1.0));
        }
      }
    });

    test('repeats exactly every 1.0', () {
      final a = equalizerBarHeights(0.3);
      final b = equalizerBarHeights(1.3);
      for (var i = 0; i < a.length; i++) {
        expect(a[i], closeTo(b[i], 1e-9));
      }
    });

    test('the bars do not all move together', () {
      final h = equalizerBarHeights(0.1);
      expect(h.toSet().length, greaterThan(1));
    });

    test('the pose changes over time', () {
      expect(equalizerBarHeights(0.0), isNot(equalizerBarHeights(0.25)));
    });

    test('number of bars can be chosen', () {
      expect(equalizerBarHeights(0.5).length, 4);
      expect(equalizerBarHeights(0.5, bars: 6).length, 6);
    });
  });

  group('EqualizerIcon', () {
    testWidgets('is a 24 x 24 icon-sized box', (tester) async {
      await tester.pumpWidget(_host(false));
      expect(tester.getSize(find.byType(EqualizerIcon)), const Size(24, 24));
    });

    testWidgets('animates while playing and stops when paused',
        (tester) async {
      await tester.pumpWidget(_host(true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(_host(false));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('stays still when Reduce Motion is on', (tester) async {
      await tester.pumpWidget(_host(true, reduceMotion: true));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('can start again after a pause', (tester) async {
      await tester.pumpWidget(_host(false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host(true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.hasRunningAnimations, isTrue);
    });
  });
}
