import 'package:flutter/material.dart';

/// The heart. Filled red = favorite. Used in the library list and on
/// Now Playing. [PRD FR-005]
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onChanged,
  });

  final bool isFavorite;

  /// Called with the NEW value (true = add to favorites).
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      isSelected: isFavorite,
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      icon: const Icon(Icons.favorite_border),
      selectedIcon: const Icon(Icons.favorite, color: Colors.redAccent),
      onPressed: () => onChanged(!isFavorite),
    );
  }
}
