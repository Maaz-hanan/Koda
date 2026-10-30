import 'package:flutter/material.dart';

import '../../core/format_duration.dart';
import '../../domain/loop/loop_status.dart';
import '../shared/glass_container.dart';
import '../theme/app_theme.dart';

/// The words shown for a section loop, e.g. title "Loop 1:05 – 1:20" and
/// detail "Running · 3 left". A top-level function so tests can check the
/// exact text. [PRD FR-025]
({String title, String detail}) loopStatusText(SectionLoopStatus status) {
  final title =
      'Loop ${formatDurationMs(status.startMs)} – ${formatDurationMs(status.endMs)}';

  final String detail;
  if (status.phase == SectionLoopPhase.waiting) {
    detail = 'Waiting · starts at ${formatDurationMs(status.startMs)}';
  } else if (status.isFinite) {
    detail = 'Running · ${status.playsLeft ?? 0} left';
  } else {
    detail = 'Running · ∞';
  }
  return (title: title, detail: detail);
}

/// Shown under the transport buttons on Now Playing. [PRD FR-025, FR-042,
/// FR-043]
///
/// * While a section loop is set: a glass capsule with the range, whether the
///   loop is waiting or running, the plays left (or ∞), and the "Edit loop"
///   pill on the right.
/// * Without a loop only the "Edit loop" pill is shown.
/// The "Edit loop" button is ALWAYS visible, for people who do not know the
/// long press on the Loop button.
class LoopStatusPanel extends StatelessWidget {
  const LoopStatusPanel({
    super.key,
    required this.status,
    required this.onEdit,
  });

  /// The current section loop, or null when there is none.
  final SectionLoopStatus? status;

  /// Opens the loop editor.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final pill = FilledButton.tonal(
      onPressed: onEdit,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const StadiumBorder(),
        backgroundColor: AppColors.glassFillStrong,
        foregroundColor: AppColors.textPrimary,
      ),
      child: const Text('Edit loop'),
    );

    if (s == null) return pill;

    final text = loopStatusText(s);
    final running = s.phase == SectionLoopPhase.running;
    final accent = running ? AppColors.accent : AppColors.textSecondary;

    return GlassContainer(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: [
          // Semantics only around the text part, not around the button.
          Expanded(
            child: Semantics(
              container: true,
              label: '${text.title}. ${text.detail}',
              excludeSemantics: true,
              child: Row(
                children: [
                  Icon(running ? Icons.loop : Icons.hourglass_empty,
                      size: 20, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          text.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          text.detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          pill,
        ],
      ),
    );
  }
}
