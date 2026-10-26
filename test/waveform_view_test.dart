import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/domain/waveform/waveform_peaks.dart';
import 'package:loop_player/presentation/now_playing/waveform_view.dart';

WaveformPeaks _peaks() => WaveformPeaks(
      values: List<double>.generate(600, (i) => (i % 50) / 50),
      peaksPerSecond: 10,
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 300, child: child)),
      ),
    );

void main() {
  testWidgets('without callbacks there are no handles or labels',
      (tester) async {
    await tester.pumpWidget(_host(WaveformView(
      peaks: _peaks(),
      totalMs: 60000,
      startMs: 10000,
      endMs: 20000,
    )));
    expect(find.byKey(const Key('waveform_start_label')), findsNothing);
    expect(find.byKey(const Key('waveform_end_label')), findsNothing);
  });

  testWidgets('with callbacks the timestamps are shown', (tester) async {
    await tester.pumpWidget(_host(WaveformView(
      peaks: _peaks(),
      totalMs: 60000,
      startMs: 10000,
      endMs: 20500,
      onStartChanged: (_) {},
      onEndChanged: (_) {},
    )));
    expect(find.text('0:10'), findsOneWidget);
    expect(find.text('0:20.5'), findsOneWidget);
  });

  testWidgets('dragging the Start handle reports a new Start only',
      (tester) async {
    final starts = <int>[];
    final ends = <int>[];
    await tester.pumpWidget(_host(WaveformView(
      peaks: _peaks(),
      totalMs: 60000,
      startMs: 10000, // x = 50 of 300
      endMs: 20000, // x = 100 of 300
      onStartChanged: starts.add,
      onEndChanged: ends.add,
    )));

    final topLeft = tester.getTopLeft(find.byType(WaveformView));
    await tester.dragFrom(topLeft + const Offset(50, 60), const Offset(30, 0));
    await tester.pump();

    expect(ends, isEmpty);
    expect(starts, isNotEmpty);
    // 30 px of 300 px over 60 s = 6 s later: about 16 s.
    expect(starts.last, closeTo(16000, 300));
  });

  testWidgets('dragging the End handle reports a new End only', (tester) async {
    final starts = <int>[];
    final ends = <int>[];
    await tester.pumpWidget(_host(WaveformView(
      peaks: _peaks(),
      totalMs: 60000,
      startMs: 10000,
      endMs: 20000,
      onStartChanged: starts.add,
      onEndChanged: ends.add,
    )));

    final topLeft = tester.getTopLeft(find.byType(WaveformView));
    await tester.dragFrom(topLeft + const Offset(100, 60), const Offset(40, 0));
    await tester.pump();

    expect(starts, isEmpty);
    expect(ends, isNotEmpty);
    expect(ends.last, closeTo(28000, 300));
  });

  testWidgets('dragging far from both handles does nothing', (tester) async {
    final starts = <int>[];
    final ends = <int>[];
    await tester.pumpWidget(_host(WaveformView(
      peaks: _peaks(),
      totalMs: 60000,
      startMs: 10000, // x = 50
      endMs: 20000, // x = 100
      onStartChanged: starts.add,
      onEndChanged: ends.add,
    )));

    final topLeft = tester.getTopLeft(find.byType(WaveformView));
    await tester.dragFrom(topLeft + const Offset(250, 60), const Offset(-20, 0));
    await tester.pump();

    expect(starts, isEmpty);
    expect(ends, isEmpty);
  });
}
