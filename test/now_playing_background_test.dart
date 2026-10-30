import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/presentation/now_playing/artwork_tint.dart';
import 'package:loop_player/presentation/now_playing/now_playing_background.dart';
import 'package:loop_player/presentation/theme/app_theme.dart';

List<Color> _colors(WidgetTester tester) {
  final box = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
  final gradient = (box.decoration! as BoxDecoration).gradient! as LinearGradient;
  return gradient.colors;
}

void main() {
  testWidgets('no artwork shows the fallback gradient', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: NowPlayingBackground(artworkPath: null, child: SizedBox()),
      ),
    ));
    expect(_colors(tester), const [
      AppColors.nowPlayingGradientTop,
      AppColors.nowPlayingGradientBottom,
    ]);
  });

  testWidgets('a tint from the artwork replaces the fallback', (tester) async {
    const tint = ArtworkTint(Color(0xFF203040), Color(0xFF101820));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        artworkTintProvider('art.png').overrideWith((ref) async => tint),
      ],
      child: const MaterialApp(
        home: NowPlayingBackground(artworkPath: 'art.png', child: SizedBox()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(_colors(tester), const [Color(0xFF203040), Color(0xFF101820)]);
  });

  testWidgets('a failed tint keeps the fallback', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        artworkTintProvider('bad.png').overrideWith((ref) async => null),
      ],
      child: const MaterialApp(
        home: NowPlayingBackground(artworkPath: 'bad.png', child: SizedBox()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(_colors(tester).first, AppColors.nowPlayingGradientTop);
  });
}
