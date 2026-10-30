import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The two background colors taken from a song's artwork: a dark tint for
/// the top of the screen and a darker one for the bottom.
@immutable
class ArtworkTint {
  const ArtworkTint(this.top, this.bottom);

  final Color top;
  final Color bottom;

  @override
  bool operator ==(Object other) =>
      other is ArtworkTint && other.top == top && other.bottom == bottom;

  @override
  int get hashCode => Object.hash(top, bottom);
}

/// Works out the tint from raw RGBA pixels (4 bytes per pixel). Pure, so it
/// can be tested without images.
///
/// Transparent, near-black and near-white pixels are skipped (they carry no
/// colour). The rest are averaged, then the colour is made dark and soft:
/// saturation at most 0.45, top lightness 0.20 + 0.08 * average lightness,
/// bottom lightness 0.10 + 0.04 * average lightness. Null if no pixel counts.
ArtworkTint? tintFromRgba(Uint8List rgba) {
  var r = 0, g = 0, b = 0, count = 0;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] < 128) continue;
    final pr = rgba[i], pg = rgba[i + 1], pb = rgba[i + 2];
    final maxC = math.max(pr, math.max(pg, pb));
    final minC = math.min(pr, math.min(pg, pb));
    if (maxC < 24) continue; // near black
    if (minC > 232) continue; // near white
    r += pr;
    g += pg;
    b += pb;
    count++;
  }
  if (count == 0) return null;

  final average = Color.fromARGB(
    255,
    (r / count).round(),
    (g / count).round(),
    (b / count).round(),
  );
  final hsl = HSLColor.fromColor(average);
  final saturation = math.min(hsl.saturation, 0.45);
  return ArtworkTint(
    HSLColor.fromAHSL(1, hsl.hue, saturation, 0.20 + 0.08 * hsl.lightness)
        .toColor(),
    HSLColor.fromAHSL(1, hsl.hue, saturation, 0.10 + 0.04 * hsl.lightness)
        .toColor(),
  );
}

final Map<String, ArtworkTint> _tintCache = {};

@visibleForTesting
void clearArtworkTintCache() => _tintCache.clear();

/// Reads the artwork file, shrinks it to 16 x 16 and returns its tint.
/// Any problem (missing file, broken image) gives null, never an error.
Future<ArtworkTint?> loadArtworkTint(String path) async {
  final cached = _tintCache[path];
  if (cached != null) return cached;

  ArtworkTint? result;
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 16,
      targetHeight: 16,
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data != null) {
          result = tintFromRgba(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        }
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } catch (_) {
    result = null;
  }
  if (result != null) _tintCache[path] = result;
  return result;
}
