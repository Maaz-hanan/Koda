import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'artwork_tint.dart';

/// The tint of one artwork file (null when it has no usable colour).
final artworkTintProvider =
    FutureProvider.family<ArtworkTint?, String>((ref, path) {
  return loadArtworkTint(path);
});

/// A full-size vertical gradient tinted by the artwork. While the colour is
/// loading, or when there is no artwork, the app's fallback gradient shows.
/// The colours change smoothly over 400 ms.
class NowPlayingBackground extends ConsumerWidget {
  const NowPlayingBackground({
    super.key,
    required this.artworkPath,
    required this.child,
  });

  final String? artworkPath;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = artworkPath;
    final ArtworkTint? tint = path == null
        ? null
        : ref.watch(artworkTintProvider(path)).maybeWhen<ArtworkTint?>(
              data: (t) => t,
              orElse: () => null,
            );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint?.top ?? AppColors.nowPlayingGradientTop,
            tint?.bottom ?? AppColors.nowPlayingGradientBottom,
          ],
        ),
      ),
      child: child,
    );
  }
}
