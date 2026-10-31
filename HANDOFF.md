# HANDOFF (read this first; it is short on purpose)

Project: LoopPlayer, an iOS music player with section looping, built with
Flutter by a COMPLETE BEGINNER. Folder: ~/Developer/LoopPlayer. The owner tests
on a real iPhone. Claude's sandbox CANNOT run Flutter: never claim tests pass;
the owner runs `flutter test` / `flutter analyze` and reports.

## State right now (updated at checkpoint after UI-11 fix)
- DONE and tested by the owner on a real iPhone: Phases 1-7 + Phase 6 extras,
  Polish 1, Shuffle, UI-1 to UI-7, UI-8 (Apple-Music bottom bar), UI-9 (droplet
  tab highlight + extra haptics), UI-10 (bigger playlist rows, bar above the
  keyboard, Artist field in Edit song, search pill without red border). Auto
  Loop (Phase 5) was dropped; Albums / Artists tabs were removed on purpose.
- UI-11 (hold-lift-drag droplet, nothing switches until release): the owner ran
  it, 313 tests passed and 1 failed (a TEST bug: two pumps needed). UI-11 fix
  is WRITTEN, NOT YET RUN: that test fix + curved shuffle icon
  (CupertinoIcons.shuffle in shuffle_button, shuffle_play_button, queue_screen).
  The owner has NOT yet reported the iPhone feel of the droplet drag nor the
  new shuffle icon. Details: STATUS.md "UI-11" and "UI-11 fix".
- Also written, not run: test fix 2 (CupertinoIcons.shuffle in ui_foundation_test), app name KŌDA, new app icon. Owner installs with `flutter run --release`.
- NEXT: wait for the owner's report on the UI-11 fix (test / analyze / iPhone),
  fix ONLY what is reported. The owner may then list more small changes: one
  phase per zip. Then the owner reruns PHASE7_CHECKLIST.md.
- Last reported `flutter test`: 313 passed + 1 failed (the test bug above). The
  fix has not been run.
- Optional ideas not built are at the end of STATUS.md.

## Lessons from this project (read once)
- The sandbox has NO `dart` / `flutter`: nothing can be compiled or formatted.
  After writing Dart, at least check bracket balance and re-read your own edit.
  Typical bugs so far were found only by the owner's `flutter test`: reading a
  provider that needs the audio handler inside build(); Semantics value without
  increasedValue / decreasedValue; animations needing two pump() calls in tests.
- Before changing any widget run `grep -rn "<Widget>" test` and keep what tests
  use (Keys, texts, tooltips).
- When the owner pastes a failing test, fix the real cause; if the pasted
  output is cut off, say so and ask for the first "EXCEPTION CAUGHT" block.

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
7. Never call ref.read(audioHandlerProvider) inside build() (tests have no
   handler; read it in tap callbacks). Keep every existing widget Key / visible text used by tests (see below).
   Run-check mentally against test/ files before changing a widget:
   `grep -rn "<WidgetName>" test`.
8. If STATUS.md and the code disagree, TRUST THE CODE and tell the owner.
9. Update STATUS.md (what was done, files, tests, iPhone checks) and the
   "State right now / NEXT" part of this file in the same zip. If the owner says
   "checkpoint", stop and deliver only the updated STATUS.md + HANDOFF.md zip.

## Where things are (do not re-read everything; grep for what you need)
- Library: lib/presentation/library/ (library_screen, library_bottom_bar,
  song_list_view, edit_song_sheet, song_actions). Now Playing:
  lib/presentation/now_playing/. Queue: lib/presentation/queue/. Shared widgets
  (glass_container, mini_player, scrub_bar, circle_icon_button, artwork_widget):
  lib/presentation/shared/. Theme tokens: lib/presentation/theme/app_theme.dart.
- Audio: lib/domain/playback/audio_handler.dart (+ queue_manager.dart).
  Providers: lib/providers/. Database + repositories: lib/data/.
- Design reference: apple_music_design_profile.json (never print it whole).
