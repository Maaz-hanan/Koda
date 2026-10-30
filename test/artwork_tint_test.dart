import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/presentation/now_playing/artwork_tint.dart';

Uint8List _pixels(List<List<int>> rgba) =>
    Uint8List.fromList([for (final p in rgba) ...p]);

void main() {
  test('no usable pixels gives null', () {
    expect(tintFromRgba(Uint8List(0)), isNull);
    // black, white and transparent pixels carry no colour
    expect(
      tintFromRgba(_pixels([
        [0, 0, 0, 255],
        [255, 255, 255, 255],
        [200, 40, 40, 0],
      ])),
      isNull,
    );
  });

  test('a red picture gives a dark, soft red', () {
    final tint = tintFromRgba(_pixels([
      for (var i = 0; i < 16; i++) [220, 30, 30, 255],
    ]))!;
    final top = HSLColor.fromColor(tint.top);
    final bottom = HSLColor.fromColor(tint.bottom);

    expect(top.hue < 15 || top.hue > 345, isTrue);
    expect(top.saturation, lessThanOrEqualTo(0.47));
    expect(top.lightness, inInclusiveRange(0.19, 0.29));
    expect(bottom.lightness, inInclusiveRange(0.09, 0.15));
    expect(top.lightness, greaterThan(bottom.lightness));
  });

  test('black and white pixels are ignored in the average', () {
    const green = [40, 200, 60, 255];
    final alone = tintFromRgba(_pixels([green, green]))!;
    final mixed = tintFromRgba(_pixels([
      green,
      [0, 0, 0, 255],
      [255, 255, 255, 255],
      green,
    ]))!;
    expect(mixed, alone);
  });

  test('a missing file gives null and does not throw', () async {
    expect(await loadArtworkTint('/no/such/file.png'), isNull);
  });
}
