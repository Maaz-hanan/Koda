import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

/// The "Shuffle" pill: plays a list in random order. Used above the Songs
/// list and on playlist screens. [PRD FR-008]
class ShufflePlayButton extends StatelessWidget {
  const ShufflePlayButton({super.key, required this.onPressed});

  /// Null greys it out (e.g. an empty playlist).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: const Icon(CupertinoIcons.shuffle),
      label: const Text('Shuffle'),
    );
  }
}
