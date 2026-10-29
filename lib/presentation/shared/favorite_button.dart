import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../theme/app_theme.dart';

/// The heart. Filled red = favorite. Used in the library list and on
/// Now Playing. [PRD FR-005]
///
/// [compact] is the small, quiet heart used inside list rows: a smaller icon
/// that is grey when off.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onChanged,
    this.compact = false,
  });

  final bool isFavorite;

  /// Called with the NEW value (true = add to favorites).
  final ValueChanged<bool> onChanged;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      isSelected: isFavorite,
      iconSize: compact ? 20 : null,
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      icon: Icon(
        Icons.favorite_border,
        color: compact ? AppColors.textTertiary : null,
      ),
      selectedIcon: const Icon(Icons.favorite, color: AppColors.favoriteOn),
      onPressed: () {
        // A soft tap when a heart is added, a lighter tick when removed.
        if (isFavorite) {
          Haptics.tick();
        } else {
          Haptics.light();
        }
        onChanged(!isFavorite);
      },
    );
  }
}
