import 'dart:io';

import 'package:flutter/material.dart';

/// Album art from a file path, with a music-note placeholder when missing.
class ArtworkWidget extends StatelessWidget {
  const ArtworkWidget({
    super.key,
    required this.path,
    this.size = 48,
    this.radius = 8,
  });

  final String? path;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.music_note,
          size: size * 0.5, color: scheme.onSurfaceVariant),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: path == null
            ? placeholder
            : Image.file(
                File(path!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => placeholder,
              ),
      ),
    );
  }
}
