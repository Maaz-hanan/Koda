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
  UI-3 (Library redesign), UI-4 (Now Playing + volume), UI-5 (Queue). All owner-tested ("looks good").
- UI-4 and UI-5 DONE and owner-tested ("everything works"). Nothing pending.
- NEXT: UI-6 (loop editor sheet + final polish),
  then UI-7 (Edit song: rename + change cover from Photos, see STATUS.md;
  needs the image_picker package: ASK FIRST). Do not forget UI-7.
- Owner's last reported `flutter test` total before UI-4: 278+, all passed.

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

## UI-4 (done and owner-tested)
The old UI-4 brief was removed after it was built; STATUS.md "UI-4 (written)"
lists what was made. If the owner reports a bug, fix only that.

## UI-5, UI-6, UI-7 (later; see STATUS.md "UI REDESIGN" section for the plan)
- (UI-5 DONE) Queue screen restyle (tinted background, header, pill row: Shuffle, Loop,
  Edit loop, Add to playlist, "Up Next", SongTile-like rows; keep tap-to-jump,
  remove X, EqualizerIcon alignment tests in test/queue_screen_test.dart).
- UI-6 Loop editor sheet + waveform container restyle (keep every Key), dialogs,
  final polish, then rerun PHASE7_CHECKLIST.md.
- UI-7 Edit song (rename + cover from Photos): see STATUS.md "UI-7 (planned)".
  Ask before adding image_picker. Needs a DB change and an Info.plist key.
