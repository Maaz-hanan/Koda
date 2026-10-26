import 'package:flutter/material.dart';

import '../../core/format_duration.dart';
import '../../domain/loop/loop_status.dart';

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

/// Shown under the Loop button on Now Playing. [PRD FR-025, FR-042, FR-043]
///
/// * While a section loop is set it shows the range, whether the loop is
///   waiting or running, and the plays left (or ∞).
/// * The "Edit loop" button is ALWAYS visible, for people who do not know the
///   long press on the Loop button.
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
    final scheme = Theme.of(context).colorScheme;
    final s = status;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (s != null) ...[
          _StatusCard(status: s),
          const SizedBox(height: 4),
        ],
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit loop'),
          style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final SectionLoopStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = loopStatusText(status);
    final running = status.phase == SectionLoopPhase.running;
    final accent = running ? scheme.tertiary : scheme.onSurfaceVariant;

    return Semantics(
      container: true,
      label: '${text.title}. ${text.detail}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(running ? Icons.loop : Icons.hourglass_empty,
                size: 20, color: accent),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text.title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(text.detail,
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
