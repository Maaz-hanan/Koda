import 'package:flutter/material.dart';

import '../shared/circle_icon_button.dart';

/// The shuffle on / off switch on Now Playing. On = accent icon.
/// [PRD FR-008]
class ShuffleButton extends StatelessWidget {
  const ShuffleButton({super.key, required this.isOn, required this.onPressed});

  final bool isOn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: Icons.shuffle,
      active: isOn,
      tooltip: isOn ? 'Shuffle: on' : 'Shuffle: off',
      onPressed: onPressed,
    );
  }
}
