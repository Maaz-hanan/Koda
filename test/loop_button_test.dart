import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/domain/loop/loop_mode.dart';
import 'package:loop_player/presentation/now_playing/loop_button.dart';

/// A tiny stand-in screen: holds the mode and wires the button like the real
/// Now Playing screen does (tap = cycle, long press = count it).
class _Harness extends StatefulWidget {
  const _Harness({required this.onModeChanged, required this.onLongPress});
  final void Function(LoopMode) onModeChanged;
  final VoidCallback onLongPress;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  LoopMode mode = LoopMode.off;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: LoopButton(
            mode: mode,
            onTap: () {
              setState(() => mode = nextRepeatMode(mode));
              widget.onModeChanged(mode);
            },
            onLongPress: widget.onLongPress,
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('three taps: off -> once -> infinite -> off', (tester) async {
    final seen = <LoopMode>[];
    await tester.pumpWidget(
        _Harness(onModeChanged: seen.add, onLongPress: () {}));

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(LoopButton));
      await tester.pump();
    }
    expect(seen,
        [LoopMode.repeatOnce, LoopMode.repeatInfinite, LoopMode.off]);
  });

  testWidgets('long press opens the editor and does NOT change the mode',
      (tester) async {
    final seen = <LoopMode>[];
    var longPresses = 0;
    await tester.pumpWidget(_Harness(
        onModeChanged: seen.add, onLongPress: () => longPresses++));

    await tester.longPress(find.byType(LoopButton));
    await tester.pump();

    expect(longPresses, 1);
    expect(seen, isEmpty); // the tap cycle never ran
  });

  testWidgets('shows a different icon for each repeat mode', (tester) async {
    Future<void> show(LoopMode m) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: LoopButton(mode: m, onTap: () {}, onLongPress: () {}),
          ),
        ));

    await show(LoopMode.off);
    expect(find.byIcon(Icons.repeat), findsOneWidget);
    expect(find.text('∞'), findsNothing);

    await show(LoopMode.repeatOnce);
    expect(find.byIcon(Icons.repeat_one), findsOneWidget);

    await show(LoopMode.repeatInfinite);
    expect(find.byIcon(Icons.repeat), findsOneWidget);
    expect(find.text('∞'), findsOneWidget);
  });
}
