import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/presentation/now_playing/volume_slider.dart';
import 'package:loop_player/presentation/shared/scrub_bar.dart';

void main() {
  testWidgets('shows both speaker icons and the volume as a percentage',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VolumeSlider(
            value: 0.5, onChanged: (_) {}, onChangeEnd: (_) {}),
      ),
    ));
    expect(find.byIcon(Icons.volume_mute), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.bySemanticsLabel('Volume'), findsOneWidget);
    expect(
        tester.widget<ScrubBar>(find.byType(ScrubBar)).semanticFormat!(0.5),
        '50%');
  });

  testWidgets('a tap in the middle gives about half volume', (tester) async {
    final ended = <double>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: VolumeSlider(
                value: 0, onChanged: (_) {}, onChangeEnd: ended.add),
          ),
        ),
      ),
    ));
    await tester.tapAt(tester.getCenter(find.byType(ScrubBar)));
    expect(ended.single, closeTo(0.5, 0.05));
  });
}
