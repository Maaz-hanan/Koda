import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/domain/loop/loop_status.dart';
import 'package:loop_player/presentation/now_playing/loop_status_panel.dart';

void main() {
  Widget host(SectionLoopStatus? status, {VoidCallback? onEdit}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: LoopStatusPanel(status: status, onEdit: onEdit ?? () {}),
          ),
        ),
      );

  const waitingFinite = SectionLoopStatus(
    startMs: 65000,
    endMs: 80000,
    isFinite: true,
    phase: SectionLoopPhase.waiting,
    playsLeft: 3,
  );
  const runningFinite = SectionLoopStatus(
    startMs: 65000,
    endMs: 80000,
    isFinite: true,
    phase: SectionLoopPhase.running,
    playsLeft: 3,
  );
  const runningInfinite = SectionLoopStatus(
    startMs: 65000,
    endMs: 80000,
    isFinite: false,
    phase: SectionLoopPhase.running,
  );

  test('text for waiting, running finite and running infinite', () {
    final w = loopStatusText(waitingFinite);
    expect(w.title, 'Loop 1:05 – 1:20');
    expect(w.detail, 'Waiting · starts at 1:05');

    expect(loopStatusText(runningFinite).detail, 'Running · 3 left');
    expect(loopStatusText(runningInfinite).detail, 'Running · ∞');
  });

  testWidgets('no loop: only the Edit loop button is shown', (tester) async {
    await tester.pumpWidget(host(null));
    expect(find.text('Edit loop'), findsOneWidget);
    expect(find.textContaining('Loop 1:05'), findsNothing);
    expect(find.textContaining('Running'), findsNothing);
    expect(find.textContaining('Waiting'), findsNothing);
  });

  testWidgets('waiting loop shows the range and when it starts',
      (tester) async {
    await tester.pumpWidget(host(waitingFinite));
    expect(find.text('Loop 1:05 – 1:20'), findsOneWidget);
    expect(find.text('Waiting · starts at 1:05'), findsOneWidget);
    expect(find.text('Edit loop'), findsOneWidget);
  });

  testWidgets('running finite loop shows plays left', (tester) async {
    await tester.pumpWidget(host(runningFinite));
    expect(find.text('Running · 3 left'), findsOneWidget);
  });

  testWidgets('running infinite loop shows the infinity sign', (tester) async {
    await tester.pumpWidget(host(runningInfinite));
    expect(find.text('Running · ∞'), findsOneWidget);
  });

  testWidgets('Edit loop calls onEdit', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(null, onEdit: () => taps++));
    await tester.tap(find.text('Edit loop'));
    await tester.pump();
    expect(taps, 1);
  });
}
