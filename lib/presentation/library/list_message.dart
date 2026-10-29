import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A centred message for an empty list. If [text] has several lines, the
/// first line is the bold title and the rest is the explanation
/// ("No favorites yet.\nTap the heart on a song to add it."). A single line
/// is shown as plain secondary text ("No songs match "x"."). An optional big
/// quiet [icon] goes on top.
class ListMessage extends StatelessWidget {
  const ListMessage(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final hasBody = lines.length > 1;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 64, color: AppColors.textTertiary),
              const SizedBox(height: 16),
            ],
            Text(
              hasBody ? lines.first : text,
              textAlign: TextAlign.center,
              style: hasBody
                  ? const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )
                  : const TextStyle(
                      fontSize: 17,
                      color: AppColors.textSecondary,
                    ),
            ),
            if (hasBody) ...[
              const SizedBox(height: 8),
              Text(
                lines.skip(1).join('\n'),
                textAlign: TextAlign.center,
                style: AppText.rowSubtitle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
