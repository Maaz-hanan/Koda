import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../providers/audio_handler_provider.dart';
import '../../providers/search_provider.dart';
import '../shared/glass_container.dart';
import '../shared/mini_player.dart';
import '../theme/app_theme.dart';

/// The Library's four sections, in order. Used by the bottom bar and by the
/// pages in the library screen.
class LibraryTab {
  const LibraryTab(this.label, this.icon);

  final String label;
  final IconData icon;

  static const all = [
    LibraryTab('Songs', Icons.music_note),
    LibraryTab('Playlists', Icons.queue_music),
    LibraryTab('Favorites', Icons.favorite),
    LibraryTab('Recents', Icons.history),
  ];
}

enum _BarMode { tabs, collapsed, search }

/// Apple-Music-style floating bar at the bottom of the Library.
///
/// * Tabs open: the mini player sits ABOVE a glass tab pill (Songs, Playlists,
///   Favorites, Recents) and a round search button.
/// * Tabs collapsed ([collapsed] true, set by scrolling a list down): ONE row
///   with the selected tab's round icon, the mini player in the middle, and
///   the search button. Tap the round icon to open the tabs again.
/// * Search: the mini player stays on top and the tab pill turns into a
///   search field with a round close button. Closing clears the search.
class LibraryBottomBar extends ConsumerStatefulWidget {
  const LibraryBottomBar({
    super.key,
    required this.controller,
    required this.collapsed,
  });

  /// The controller of the pages (its index is the selected tab).
  final TabController controller;

  /// True while the tabs are collapsed.
  final ValueNotifier<bool> collapsed;

  @override
  ConsumerState<LibraryBottomBar> createState() => _LibraryBottomBarState();
}

class _LibraryBottomBarState extends ConsumerState<LibraryBottomBar>
    with TickerProviderStateMixin {
  static const double _button = 56;
  static const double _gap = 8;

  bool _searching = false;
  late final TextEditingController _text;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: ref.read(searchQueryProvider));
    _lastTab = widget.controller.index;
    widget.controller.animation?.addListener(_onTabMove);
    _lift = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160))
      ..addListener(() => setState(() {}));
    _settle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320))
      ..addListener(_onSettleTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // Hand the droplet back to the pages (they have arrived too).
          setState(() => _dragPos = null);
        }
      });
  }

  int _lastTab = 0;

  // ---- holding and dragging the droplet (like Apple's tab bar) ----
  // Press the droplet: it lifts (gets bigger). Drag: it follows the finger and
  // NOTHING switches. Lift the finger: it settles on the nearest tab, lowers,
  // and only then, if that tab is a different one, the page changes.
  late final AnimationController _lift; // 0 = flat, 1 = lifted
  late final AnimationController _settle; // droplet gliding to its tab
  double _slotWidth = 0;
  double? _dragPos; // droplet position while held / settling, else null
  int? _pointer; // the finger that holds the droplet
  double _grabOffset = 0; // finger x minus droplet centre at the grab
  int _hoverTab = 0;
  double _settleFrom = 0;
  int _settleTo = 0;

  void _onSettleTick() {
    final t = Curves.easeOutCubic.transform(_settle.value);
    setState(() => _dragPos = _settleFrom + (_settleTo - _settleFrom) * t);
  }

  void _pointerDown(PointerDownEvent e) {
    final c = widget.controller;
    if (_pointer != null || _slotWidth <= 0) return;
    // A page animation or a settle is still running: ignore this touch.
    if (c.indexIsChanging || _settle.isAnimating) return;
    final pos = c.animation?.value ?? c.index.toDouble();
    final centre = _slotWidth * (pos + 0.5);
    // Only a press ON the droplet picks it up.
    if ((e.localPosition.dx - centre).abs() > _slotWidth / 2) return;
    _pointer = e.pointer;
    _grabOffset = e.localPosition.dx - centre;
    _dragPos = pos;
    _hoverTab = pos.round();
    _lift.forward();
    Haptics.tick(); // picked up
  }

  void _pointerMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final last = (LibraryTab.all.length - 1).toDouble();
    final pos = ((e.localPosition.dx - _grabOffset) / _slotWidth - 0.5)
        .clamp(0.0, last)
        .toDouble();
    if (pos.round() != _hoverTab) {
      _hoverTab = pos.round();
      Haptics.tick(); // passing over another tab
    }
    setState(() => _dragPos = pos);
  }

  void _pointerEnd(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final from = _dragPos ?? widget.controller.index.toDouble();
    final target =
        from.round().clamp(0, LibraryTab.all.length - 1);
    _lift.reverse();
    _settleFrom = from;
    _settleTo = target;
    _settle.forward(from: 0);
    // Now (and only now) the page switches.
    if (target != widget.controller.index) {
      widget.controller.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// One tick each time the droplet passes the middle between two tabs
  /// (taps and swipes alike).
  void _onTabMove() {
    final v = widget.controller.animation?.value;
    if (v == null) return;
    final r = v.round();
    if (r != _lastTab) {
      _lastTab = r;
      // While the droplet is held or settling, _pointerMove already ticked.
      if (_dragPos == null) Haptics.tick();
    }
  }

  @override
  void dispose() {
    widget.controller.animation?.removeListener(_onTabMove);
    _lift.dispose();
    _settle.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _openSearch() {
    Haptics.tick();
    setState(() => _searching = true);
  }

  void _closeSearch() {
    Haptics.tick();
    _text.clear();
    ref.read(searchQueryProvider.notifier).set('');
    _focus.unfocus();
    setState(() => _searching = false);
  }

  Widget _circle({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = AppColors.textPrimary,
  }) {
    return SizedBox(
      key: key,
      width: _button,
      height: _button,
      child: GlassContainer(
        radius: _button / 2,
        child: IconButton(
          iconSize: 26,
          tooltip: tooltip,
          color: color,
          icon: Icon(icon),
          onPressed: onPressed,
        ),
      ),
    );
  }

  /// The tab pill. One glass "droplet" slides behind the icons. While it
  /// travels it stretches (like a water drop) and gets a little thinner, then
  /// settles. It follows the page position, so it works for taps and swipes.
  Widget _tabsPill() {
    final c = widget.controller;
    final count = LibraryTab.all.length;
    final held = _dragPos != null;
    final lift = _lift.value;
    final pos = (_dragPos ?? c.animation?.value ?? c.index.toDouble())
        .clamp(0.0, (count - 1).toDouble())
        .toDouble();
    final selected = pos.round().clamp(0, count - 1);

    // bump: 0 at rest, 1 half way between two tabs. For a tap that jumps
    // several tabs it is measured over the whole trip, so it stretches once.
    var bump = 0.0;
    var span = 1.0;
    if (!held && c.indexIsChanging && c.index != c.previousIndex) {
      final from = c.previousIndex;
      final to = c.index;
      final p = ((pos - from) / (to - from)).clamp(0.0, 1.0).toDouble();
      bump = math.sin(math.pi * p);
      span = (to - from).abs().toDouble();
    } else {
      bump = math.sin(math.pi * (pos - pos.floorToDouble()));
    }

    return GlassContainer(
      radius: 32,
      padding: const EdgeInsets.all(4),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _pointerDown,
        onPointerMove: _pointerMove,
        onPointerUp: _pointerEnd,
        onPointerCancel: _pointerEnd,
        child: SizedBox(
        height: 56,
        child: LayoutBuilder(
          builder: (context, box) {
            final slot = box.maxWidth / count;
            _slotWidth = slot;
            // Held: bigger (lift) and only a little stretch while moving.
            final k = held ? 0.4 : 1.0;
            final w = slot * (1 + 0.35 * bump * span * k) + 14 * lift;
            final h = 56 + 8 * lift - 8 * bump * k;
            final left = (slot * (pos + 0.5) - w / 2)
                .clamp(-4.0, math.max(-4.0, box.maxWidth - w + 4))
                .toDouble();
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  key: const Key('library_tab_droplet'),
                  left: left,
                  top: (56 - h) / 2,
                  width: w,
                  height: h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                          Colors.white.withValues(alpha: 0.10 * lift),
                          AppColors.glassFillStrong),
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < count; i++)
                      Expanded(child: _tabItem(i, selected, pos)),
                  ],
                ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }

  Widget _tabItem(int i, int selected, double pos) {
    // 1 when the droplet is exactly on this tab, 0 when it is a tab away.
    final near = (1 - (pos - i).abs()).clamp(0.0, 1.0).toDouble();
    final color = Color.lerp(AppColors.textPrimary, AppColors.accent, near)!;
    return Semantics(
      button: true,
      selected: i == selected,
      label: LibraryTab.all[i].label,
      excludeSemantics: true,
      onTap: () => _selectTab(i),
      child: GestureDetector(
        key: Key('library_tab_$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectTab(i),
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LibraryTab.all[i].icon, size: 24, color: color),
              const SizedBox(height: 2),
              Text(
                LibraryTab.all[i].label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectTab(int i) {
    // The tick is fired by _onTabMove, so taps and swipes feel the same.
    widget.controller.animateTo(i);
  }

  Widget _searchField() {
    final hasText = ref.watch(searchQueryProvider).isNotEmpty;
    return SizedBox(
      height: _button,
      child: GlassContainer(
        radius: _button / 2,
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const Key('library_search_field'),
                controller: _text,
                focusNode: _focus,
                autofocus: true,
                textInputAction: TextInputAction.search,
                cursorColor: AppColors.accent,
                style: const TextStyle(
                    fontSize: 17, color: AppColors.textPrimary),
                // The app theme gives every text field a filled box and a red
                // focus border. Switch all of that off: the glass pill is
                // the field.
                decoration: const InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Search songs, artists, albums',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                ),
                onChanged: (v) =>
                    ref.read(searchQueryProvider.notifier).set(v),
                onSubmitted: (_) => _focus.unfocus(),
              ),
            ),
            if (hasText)
              IconButton(
                icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                tooltip: 'Clear search',
                onPressed: () {
                  Haptics.tick();
                  _text.clear();
                  ref.read(searchQueryProvider.notifier).set('');
                },
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSong = ref.watch(currentMediaItemProvider).maybeWhen(
          data: (item) => item != null,
          orElse: () => false,
        );
    final animation = widget.controller.animation ?? widget.controller;

    return ValueListenableBuilder<bool>(
      valueListenable: widget.collapsed,
      builder: (context, collapsedValue, _) {
        final mode = _searching
            ? _BarMode.search
            : (collapsedValue ? _BarMode.collapsed : _BarMode.tabs);

        return ListenableBuilder(
          listenable: animation,
          builder: (context, _) {
            final selected = (widget.controller.animation?.value ??
                    widget.controller.index.toDouble())
                .round()
                .clamp(0, LibraryTab.all.length - 1);

            final searchButton = _circle(
              key: const Key('library_search_button'),
              icon: Icons.search,
              tooltip: 'Search',
              onPressed: _openSearch,
            );

            final Widget content;
            switch (mode) {
              case _BarMode.tabs:
                content = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasSong) ...[
                      const MiniPlayer(embedded: true),
                      const SizedBox(height: _gap),
                    ],
                    Row(
                      children: [
                        Expanded(child: _tabsPill()),
                        const SizedBox(width: _gap),
                        searchButton,
                      ],
                    ),
                  ],
                );
              case _BarMode.collapsed:
                content = Row(
                  children: [
                    _circle(
                      key: const Key('library_tabs_button'),
                      icon: LibraryTab.all[selected].icon,
                      tooltip: 'Show tabs',
                      color: AppColors.accent,
                      onPressed: () {
                        Haptics.tick();
                        widget.collapsed.value = false;
                      },
                    ),
                    const SizedBox(width: _gap),
                    const Expanded(
                      child: MiniPlayer(embedded: true, showSkip: false),
                    ),
                    const SizedBox(width: _gap),
                    searchButton,
                  ],
                );
              case _BarMode.search:
                content = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasSong) ...[
                      const MiniPlayer(embedded: true),
                      const SizedBox(height: _gap),
                    ],
                    Row(
                      children: [
                        Expanded(child: _searchField()),
                        const SizedBox(width: _gap),
                        _circle(
                          key: const Key('library_close_search'),
                          icon: Icons.close,
                          tooltip: 'Close search',
                          onPressed: _closeSearch,
                        ),
                      ],
                    ),
                  ],
                );
            }

            // Sits on the home-indicator area, or ON TOP OF the keyboard while
            // it is open. The keyboard height is animated by the phone, so the
            // whole bar glides up and down with it.
            final media = MediaQuery.of(context);
            final bottomInset =
                math.max(media.padding.bottom, media.viewInsets.bottom);
            return Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset),
              child: Padding(
                padding: EdgeInsets.zero,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.bottomCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(mode),
                      child: content,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
