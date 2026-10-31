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

class _LibraryBottomBarState extends ConsumerState<LibraryBottomBar> {
  static const double _button = 56;
  static const double _gap = 8;

  bool _searching = false;
  late final TextEditingController _text;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
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

  Widget _tabsPill(int selected) {
    return GlassContainer(
      radius: 32,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < LibraryTab.all.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                label: LibraryTab.all[i].label,
                excludeSemantics: true,
                onTap: () => _selectTab(i),
                child: GestureDetector(
                  key: Key('library_tab_$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _selectTab(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 56,
                    decoration: BoxDecoration(
                      color: i == selected
                          ? AppColors.glassFillStrong
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LibraryTab.all[i].icon,
                          size: 24,
                          color: i == selected
                              ? AppColors.accent
                              : AppColors.textPrimary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          LibraryTab.all[i].label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: i == selected
                                ? AppColors.accent
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _selectTab(int i) {
    Haptics.tick();
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
                decoration: const InputDecoration.collapsed(
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
                        Expanded(child: _tabsPill(selected)),
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

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
