# HANDOFF (read this first; it is short on purpose)

Project: LoopPlayer, an iOS music player with section looping, built with
Flutter by a COMPLETE BEGINNER. Folder: ~/Developer/LoopPlayer. The owner tests
on a real iPhone. Claude's sandbox CANNOT run Flutter: never claim tests pass;
the owner runs `flutter test` / `flutter analyze` and reports.

## State right now
- Phases 1-7 and Phase 6 extras (6-1..6-7) are DONE and tested by the owner.
  Auto Loop (Phase 5) was dropped. Albums/Artists tabs were removed on purpose.
- Done since: Polish 1 (queue alignment, live equalizer bars, haptics),
  Shuffle, UI-1 (theme/glass), UI-2 (floating glass mini player),
  UI-3 (Library redesign). All owner-tested ("looks good").
- NEXT: UI-4 = Now Playing redesign + volume slider. NOTHING of it is written.
- After that: UI-5 (Queue screen), UI-6 (loop editor sheet + final polish).
- Owner's last reported `flutter test` total after UI-3: not reported (ask).

## How to work (the owner's rules)
1. First message: read this file, then ONLY what the phase needs (below), then
   tell me in <= 15 lines what you understand. Do NOT write code before that.
2. One phase per reply. Deliver ONE zip with only the changed/new files PLUS the
   updated STATUS.md and HANDOFF.md, then call present_files. The zip paths are
   relative to the project root so `unzip -o` works.
3. After the zip give exactly these commands (replace the zip name):
   cd ~/Developer/LoopPlayer
   unzip -o ~/Downloads/<name>.zip
   flutter pub get
   flutter test
   flutter analyze
   flutter devices
   flutter run -d <iPhone ID>
   plus the list of iPhone checks. Say clearly it is NOT yet run by anyone.
4. No new packages and no database change without asking first. (Only dev
   package so far: sqflite_common_ffi, already approved.)
5. Do NOT invent Flutter / package APIs. If unsure, web-search once (Flutter
   3.44 renamed theme classes: DialogThemeData, AppBarThemeData,
   InputDecorationThemeData, TabBarThemeData, CardThemeData).
6. TOKEN ECONOMY (the owner has a small limit): never cat big files. Use
   `grep -n`, `sed -n 'a,bp'`. Never print the whole STATUS.md or the whole
   design profile. Write each file ONCE (heredoc), no rewrite loops, no long
   explanations, no repeated web searches. Keep replies short.
7. Keep every existing widget Key / visible text used by tests (see below).
   Run-check mentally against test/ files before changing a widget:
   `grep -rn "<WidgetName>" test`.
8. If STATUS.md and the code disagree, TRUST THE CODE and tell the owner.
9. Update STATUS.md (what was done, files, tests, iPhone checks) and the
   "State right now / NEXT" part of this file in the same zip. If the owner says
   "checkpoint", stop and deliver only the updated STATUS.md + HANDOFF.md zip.

## What to read for UI-4 (cheap)
- `grep -n "^## " STATUS.md` then `sed -n` ONLY: "About me", "How I want you to
  work", "UI REDESIGN (Apple Music iOS 26 inspired). THE PLAN." and "Next steps".
- Design profile (project root apple_music_design_profile.json), print ONLY:
  python3 -c "import json;d=json.load(open('apple_music_design_profile.json'));
  [print(k,':',v) for k,v in d['screens']['now_playing'].items()];
  [print(k,':',v) for k,v in d['dynamic_artwork_background'].items()];
  print(d['components']['ProgressBar'])"
- Code to read before editing: lib/presentation/now_playing/now_playing_screen.dart
  (whole, ~300 lines), loop_button.dart, loop_status_panel.dart,
  lib/presentation/shared/circle_icon_button.dart, scrub-related:
  none exist yet. For volume: `grep -n "restoreLastSession" -A22
  lib/domain/playback/audio_handler.dart`, lib/data/services/playback_persistence.dart.

## Facts that matter (verified in the code)
- Theme tokens: lib/presentation/theme/app_theme.dart (AppColors, AppText,
  AppSpacing, AppRadius, buildAppTheme). Dark only. Use them, no hard-coded
  colours/sizes. GlassContainer (BackdropFilter; few places only), CircleIconButton
  (44 pt glass circle: icon, onPressed, tooltip, active, size, iconSize),
  ShuffleButton, ShufflePlayButton, EqualizerIcon, PillChipRow, EmptyState,
  Haptics (tick/light/medium; lib/core/haptics.dart) all exist.
- Providers (lib/providers/audio_handler_provider.dart): audioHandlerProvider,
  currentMediaItemProvider, playbackStateProvider, positionProvider,
  repeatModeProvider, loopStatusProvider, shuffleProvider, queueProvider,
  songPlayedProvider, playbackErrorProvider. Riverpod 3: use `.when` /
  `.maybeWhen`; `.value` is nullable data.
- Screens with a list + mini player: Scaffold(extendBody: true,
  bottomNavigationBar: const MiniPlayer()).
- Now Playing opens with NowPlayingScreen.open(context) (fullscreenDialog).
  Existing Now Playing behaviour to keep: seek bar drag shows the finger
  position and seeks on release; play/pause shows a spinner while loading;
  Previous / Next; Loop button (tap cycles, long press opens LoopEditorSheet);
  'Edit loop' button; loop status; heart (toggles via songsProvider notifier,
  snackbar on error); shuffle toggle; add-to-playlist (showAddToPlaylistSheet,
  needs the live Song from songsProvider); Queue (QueueScreen.open); haptics.
- Keys/texts tests rely on: LoopButton API (mode, onTap, onLongPress; icons;
  test/loop_button_test.dart), loopStatusText() and texts 'Loop 1:05 – 1:20',
  'Waiting · starts at 1:05', 'Running · 3 left', 'Running · ∞', 'Edit loop'
  (test/loop_status_panel_test.dart), FavoriteButton tooltips, queue screen
  texts. Loop editor Keys: loop_save_button, loop_cancel_button,
  loop_start_field, loop_end_field, loop_preview_button, loop_start_plus ...
- MediaItem for artwork: `item.artUri?.toFilePath()`; songs:
  `song.absoluteArtworkPath` (needs lib/core/storage_paths.dart import).
- Settings storage: SharedPreferencesAsync (setString/getString used in
  playback_persistence.dart, key 'last_playback_v1'); it also has
  setDouble/getDouble.

## UI-4 BRIEF (ready to implement; decisions already made with the owner)
Goal: Now Playing looks like Apple Music (inspired, not a copy) + volume slider.
Keep ALL behaviour listed above. Owner decisions: Shuffle is in; no crossfade /
lyrics / AirPlay / continue-playing; bottom row uses OUR features; volume
slider IS wanted (default = the app's own volume via just_audio
player.setVolume(0..1), saved between launches, NO new package; tell the owner
it is the app volume relative to the phone volume; system volume would need a
package, ask first).
Files to CREATE:
1. lib/presentation/now_playing/artwork_tint.dart: `ArtworkTint(top, bottom)`
   (==/hashCode); pure `ArtworkTint? tintFromRgba(Uint8List)`: skip pixels with
   alpha < 128, near-black (max channel < 24) and near-white (min channel >
   232); average the rest (null if none); HSLColor: saturation = min(s, 0.45);
   top lightness = 0.20 + 0.08*avgL, bottom = 0.10 + 0.04*avgL, same hue.
   `Future<ArtworkTint?> loadArtworkTint(String path)` : File.readAsBytes ->
   ui.instantiateImageCodec(targetWidth:16,targetHeight:16) -> frame.image
   .toByteData(rawRgba) -> tintFromRgba; dispose image+codec; any error -> null;
   in-memory cache keyed by path (+ @visibleForTesting clearArtworkTintCache).
2. lib/presentation/now_playing/now_playing_background.dart:
   `artworkTintProvider = FutureProvider.family<ArtworkTint?, String>`;
   `NowPlayingBackground({artworkPath, child})` ConsumerWidget: AnimatedContainer
   (400 ms) with a vertical LinearGradient [tint.top, tint.bottom], fallback
   AppColors.nowPlayingGradientTop/Bottom when no artwork / still loading / null.
3. lib/presentation/shared/scrub_bar.dart `ScrubBar({value, max, onChanged,
   onChangeEnd, enabled = true, semanticLabel, semanticValue})`: 44 pt tall hit
   area, 6 pt track (AppColors.progressTrack) that grows to 10 pt while dragging
   (AnimatedContainer 150 ms), played part = FractionallySizedBox(key:
   ValueKey('scrub_played'), widthFactor) in AppColors.progressPlayed, rounded.
   GestureDetector(opaque): onTapUp -> onChanged+onChangeEnd at that x;
   horizontal drag start/update -> onChanged(value at finger); end/cancel ->
   onChangeEnd(last). value = (dx/width).clamp(0,1)*max. Disabled: no handlers.
4. lib/presentation/now_playing/volume_slider.dart `VolumeSlider({value,
   onChanged, onChangeEnd})` pure: Row [Icons.volume_mute (20, secondary), 12,
   Expanded(ScrubBar(max: 1, semanticLabel 'Volume')), 12, Icons.volume_up].
Files to EDIT:
5. circle_icon_button.dart: add `activeColor` (default AppColors.accent).
6. loop_button.dart: keep API + badge + InkResponse + all test behaviour; new
   look: 44x44 GlassContainer(radius 22) centred in the 56 box, fill
   glassFillStrong when active else glassFill, icon AppColors.accent when
   active else AppColors.textSecondary.
7. loop_status_panel.dart: keep `loopStatusText()` and ALL texts exactly; new
   look: with a loop = GlassContainer capsule (radius 20) [icon, title 15
   semibold + detail 13 (accent while running, else secondary), 'Edit loop'
   FilledButton.tonal pill 36 pt]; without a loop = only the 'Edit loop' pill.
   Semantics only around the left text part, not the button.
8. now_playing_screen.dart REWRITE (no AppBar): AnnotatedRegion light status bar;
   NowPlayingBackground(item.artUri path); SafeArea; LayoutBuilder +
   SingleChildScrollView + ConstrainedBox(minHeight) + IntrinsicHeight + Column
   with Spacers. Order: grabber zone 44 pt (36x5 pill, onTap and swipe-down
   velocity > 300 close: Navigator.pop; Semantics 'Close'); artwork
   min(width-48, 340, height*0.38), radius AppRadius.nowPlayingArtwork, shadow,
   AnimatedScale (1.0 playing / 0.86 paused, 300 ms, Curves.easeOutBack);
   title row (title 22 bold 2 lines + artist 18 secondary, glass heart
   CircleIconButton with activeColor AppColors.favoriteOn, same toggle logic and
   haptics); seek area = ScrubBar (drag shows finger, seek on release, same as
   today) + times row (AppText.caption); transport = bare white glyphs
   Icons.fast_rewind_rounded 44 / play_arrow_rounded|pause_rounded 60 (spinner
   while loading) / fast_forward_rounded 44, tooltips unchanged, haptics
   unchanged; LoopStatusPanel under it; VolumeSlider; bottom row of four:
   ShuffleButton, LoopButton, CircleIconButton(Icons.playlist_add, 'Add to
   playlist'), CircleIconButton(Icons.queue_music, 'Queue'). Horizontal page
   padding 24.
9. audio_handler.dart: `double _volume = 1.0; double get volume; Stream<double>
   get volumeStream; Future<void> setVolume(double v, {bool save = true})`
   (clamp 0..1, emit, _player.setVolume, save via persistence); at the TOP of
   restoreLastSession load the saved volume and apply it BEFORE the saved-session
   checks (so it applies even with no saved song).
10. playback_persistence.dart: saveVolume(double) / loadVolume() with
    SharedPreferencesAsync setDouble/getDouble, key 'player_volume_v1',
    try/catch like the others.
11. audio_handler_provider.dart: `VolumeNotifier extends Notifier<double>`
    (listen to volumeStream, initial handler.volume) + `volumeProvider`.
Tests to ADD: test/artwork_tint_test.dart (tintFromRgba: reddish hue, sat <= 0.45,
lightness ranges, black/white/transparent skipped -> null, only the colour of
mixed black+green counts, top lighter than bottom; background widget with a
provider override and the fallback; loadArtworkTint on a missing file -> null),
test/scrub_bar_test.dart (played width = value/max, tap, drag, disabled,
VolumeSlider icons + callbacks). Existing loop_button_test and
loop_status_panel_test must keep passing.
iPhone checks to list: gradient follows the artwork colour and animates between
songs; artwork shrinks when paused and grows on play; seek bar thickens while
dragging and seeks on release; volume slider changes the loudness and is
remembered after restarting the app; heart / shuffle / loop (tap + long press)
/ Edit loop / add to playlist / queue all still work; swipe down or tap the
grabber closes; small screens scroll instead of overflowing.
Then update STATUS.md ("UI-4 WRITTEN, NOT YET RUN by the owner") and the
"State right now / NEXT" part of this file (NEXT becomes UI-5).

## UI-5 and UI-6 (later; see STATUS.md "UI REDESIGN" section for the plan)
- UI-5 Queue screen restyle (tinted background, header, pill row: Shuffle, Loop,
  Edit loop, Add to playlist, "Up Next", SongTile-like rows; keep tap-to-jump,
  remove X, EqualizerIcon alignment tests in test/queue_screen_test.dart).
- UI-6 Loop editor sheet + waveform container restyle (keep every Key), dialogs,
  final polish, then rerun PHASE7_CHECKLIST.md.
