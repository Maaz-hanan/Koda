import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/presentation/shared/scrub_bar.dart';

Widget _host(ScrubBar bar) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 200, child: bar)),
      ),
    );

void main() {
  testWidgets('played part is value / max of the track width', (tester) async {
    await tester.pumpWidget(_host(const ScrubBar(value: 25, max: 100)));
    expect(tester.getSize(find.byKey(const ValueKey('scrub_played'))).width,
        closeTo(50, 0.5));
  });

  testWidgets('a tap reports the tapped value on change and end',
      (tester) async {
    final changed = <double>[];
    final ended = <double>[];
    await tester.pumpWidget(_host(ScrubBar(
      value: 0,
      max: 100,
      onChanged: changed.add,
      onChangeEnd: ended.add,
    )));
    final left = tester.getTopLeft(find.byType(ScrubBar));
    await tester.tapAt(left + const Offset(50, 22));
    expect(changed.last, closeTo(25, 0.5));
    expect(ended, hasLength(1));
    expect(ended.single, closeTo(25, 0.5));
  });

  testWidgets('a drag reports values, then ends once; bar grows while dragging',
      (tester) async {
    final changed = <double>[];
    final ended = <double>[];
    await tester.pumpWidget(_host(ScrubBar(
      value: 50,
      max: 100,
      onChanged: changed.add,
      onChangeEnd: ended.add,
    )));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ScrubBar)));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump(); // starts the grow animation
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(find.byKey(const ValueKey('scrub_played'))).height,
        10);
    expect(ended, isEmpty);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(ended, hasLength(1));
    expect(ended.single, closeTo(changed.last, 0.001));
    expect(ended.single, greaterThan(70));
    expect(tester.getSize(find.byKey(const ValueKey('scrub_played'))).height,
        6);
  });

  testWidgets('disabled bar ignores taps', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_host(ScrubBar(
      value: 0,
      max: 100,
      enabled: false,
      onChanged: (_) => calls++,
      onChangeEnd: (_) => calls++,
    )));
    await tester.tap(find.byType(ScrubBar));
    expect(calls, 0);
  });
}
