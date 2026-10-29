import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A horizontally scrolling row of pill-shaped chips, like the section
/// filters in Apple Music. Exactly one chip is selected. When the selection
/// changes (a tap, or a swipe between pages) the row scrolls so the selected
/// chip is fully visible.
class PillChipRow extends StatefulWidget {
  const PillChipRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<PillChipRow> createState() => _PillChipRowState();
}

class _PillChipRowState extends State<PillChipRow> {
  late final List<GlobalKey> _keys =
      List.generate(widget.labels.length, (_) => GlobalKey());

  @override
  void didUpdateWidget(PillChipRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = _keys[widget.selectedIndex].currentContext;
        if (target == null) return;
        Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
        child: Row(
          children: [
            for (var i = 0; i < widget.labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _Chip(
                key: _keys[i],
                label: widget.labels[i],
                selected: i == widget.selectedIndex,
                onTap: () => widget.onSelected(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.chipSelected : AppColors.chipUnselected,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.black : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
