import 'package:flutter/material.dart';

import '../shared/scrub_bar.dart';
import '../theme/app_theme.dart';

/// Speaker-low icon, bar, speaker-high icon. Pure: the screen decides what
/// the value means. [value] runs from 0 to 1.
class VolumeSlider extends StatelessWidget {
  const VolumeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.volume_mute, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: ScrubBar(
            value: value,
            max: 1,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            semanticLabel: 'Volume',
            semanticFormat: (v) => '${(v * 100).round()}%',
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.volume_up, size: 20, color: AppColors.textSecondary),
      ],
    );
  }
}
