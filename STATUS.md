# LoopPlayer — Handoff Status

> Lines marked **<CONFIRM>** are things only the owner can confirm. A new AI
> chat must NOT guess them. Update this file after every tested step.

## About me
Complete beginner, building my first iOS app. Mac (macOS 15), Xcode 26.2,
Flutter 3.44.0 / Dart 3.12. Tested on iPhone 17 Simulator AND a real iPhone 13
(iOS 26.6.1, USB-C to Lightning cable).
Project folder: ~/Developer/LoopPlayer (moved out of Desktop because iCloud
metadata caused "CodeSign failed"). The project is a git repo.
I edit code in VS Code. Xcode is only for building/signing.
Bundle ID: com.uniquema.loopplayer (free Apple ID signing; the build expires
after ~7 days and is simply rebuilt).
Run on phone: `flutter devices`, then `flutter run -d <iPhone ID>`
(the device NAME did not match once; use the ID).

## How I want you to work
- Small steps; give me complete files in a zip that unzips over my project
  (`unzip -o ~/Downloads/<name>.zip` from the project folder), plus exact
  Terminal commands.
- I run the code and paste errors back. You cannot run Flutter.
- Read my actual files before changing anything. Do NOT guess at code
  that isn't in front of you; if unsure, ask me to paste the file.
- Verify package APIs with a web search before using them (versions changed).
- Do not claim a feature works until I've tested it.
- Do not add or remove packages without asking me.
- PRD.md and LoopPlayer_Plan.md in this folder are the spec.
- Before writing code, tell me what you understand the current state to be.
- I use two AI tools on this project (Claude chats and Antigravity). Only one
  edits the project at a time. Code may have been written by either.

## Done and tested by me
- Phase 1A: scaffold, packages, background-audio flag in Info.plist, iOS 14 target.
- Phase 1B: sqflite database (songs + loop_profiles tables), Song and
  LoopProfile models, DAOs, repositories, Riverpod providers; import from
  Files app (file_picker -> copy into app storage -> read tags -> save),
  multi-select; search; remove song with confirmation.
- Phase 1C-1/1C-2: audio engine (LoopPlayerAudioHandler, QueueManager), tap to
  play, auto-advance, mini-player, Now Playing screen (artwork, seek bar,
  prev/play/next).
- Phase 1C-3 (simulator AND real iPhone, all passed): last song, queue and
  position saved (shared_preferences, JSON string) and restored PAUSED at launch;
  background audio; lock screen / Control Centre controls; call interruption;
  headphone unplug pauses.
  Files: lib/domain/playback/playback_restore.dart,
  lib/data/services/playback_persistence.dart.
- Phase 2 (real iPhone, all passed): Loop button. Tap cycles
  Off -> Repeat once -> Repeat infinite -> Off; long-press opens the editor.
  Logic in lib/domain/loop/whole_song_repeat.dart (pure Dart, unit-tested);
  UI in lib/presentation/now_playing/loop_button.dart.
- Phase 3 (section loops): I report it works on the real iPhone, with ONE
  issue (below, now fixed in code, awaiting retest). Specific checks I have
  done: <CONFIRM which: finite N plays / infinite >20 plays / pause-resume /
  seek inside / seek outside / in-app Next / lock-screen Next /
  Control Centre Next / profile survives restart / other song keeps its own>.
- Phase 4 (waveform, handles, Preview): done and tested, see the Phase 4 section.

## Phase 3 — what exists (written by Claude 3-1 + Antigravity 3-2)
- Editor: lib/presentation/now_playing/loop_editor_sheet.dart (Off / Finite /
  Infinite, Start, End, play count, "Use current", Save/Cancel). Save writes
  the LoopProfile (LoopProfileRepository), then applies it to the playing song
  through loopProfileApplierProvider -> handler.applyLoopProfile().
  lib/core/loop_time.dart parses/formats "1:05", "65", "1:05.5".
- Engine (pure Dart, unit-tested): lib/domain/loop/section_loop_engine.dart and
  active_loop_session.dart. The handler feeds it just_audio position events and
  does what it returns (seekToStart / loopCompleted). Handler integration:
  lib/domain/playback/audio_handler.dart (_onPositionChanged, _onTrackCompleted,
  seek, skipToNext/Previous, _loadCurrentAndPlay loads the song's profile).
- Next from ANY source goes through skipToNext() -> _endRepeat() which cancels
  whole-song repeat and the section session first, so Next always wins.
- Unit tests: Antigravity reported "70/70 pass" before the latest change.
  Re-run `flutter test` and note the real number here: <CONFIRM>.

## Armed-loop change (Claude, after Phase 3) — owner reports everything works
Issue I found: saving a custom loop while the song was playing JUMPED the
playhead to the loop start and the loop began immediately.
Wanted: the loop is only SET (armed). The song keeps playing normally and the
loop takes over only when playback reaches the loop Start by itself
(finite or infinite).
Changes: ActiveLoopSession.entered flag; SectionLoopEngine arms first and
enters when position is inside [start, end); applyLoopProfile and
_loadCurrentAndPlay no longer seek to the loop start.
Resulting rules:
- Loop set while the playhead is before Start -> song plays on, loop starts at Start.
- Set while the playhead is inside the region -> loop starts right away (no jump).
- Set while the playhead is past End -> nothing loops until you seek back before Start.
- Manual seek before Start re-arms the loop (count restarts); seek past End
  ends a running loop (stays armed if it never started); seek inside keeps it.
- Song ending while the loop never started cancels the loop (mode shows Off).
- Opening a song with a saved loop no longer jumps to the loop start.
Also fixed: applyLoopProfile errors are no longer swallowed (the editor shows
"Saved, but the loop could not be applied..."); a seek into the last 200 ms of
the region no longer leaves the guard flag stuck.
Retested on the iPhone: owner reports "everything seems to be working".

## Key decisions / gotchas
- metadata_god and just_waveform REMOVED (metadata_god needs Rust). Tags are
  read with audio_metadata_reader (pure Dart). just_waveform was added in Phase 4.
- Song.filePath / artworkPath are stored RELATIVE ("music/<id>.mp3") because iOS
  app folder paths can change. Always use song.absoluteFilePath /
  song.absoluteArtworkPath (extension in lib/core/storage_paths.dart).
- file_picker v13 API: FilePicker.pickFiles(...) is static and returns
  List<PlatformFile> (empty = cancelled). There is no FilePicker.platform.
- Riverpod 3: use .when(...) on AsyncValue (not .valueOrNull).
- shared_preferences: use SharedPreferencesAsync with setString/getString/remove
  (getInt/setInt were not confirmed in the docs).
- The audio handler owns the AudioPlayer; UI only calls handler methods and
  watches audio_service streams.
- just_audio exports its own `LoopMode`. audio_handler.dart imports it with
  `hide LoopMode` so OUR LoopMode (lib/domain/loop/loop_mode.dart) is used.
  Any new file importing both must do the same.
- Whole-song repeat (Once/Infinite) is NOT saved across restarts. Section loops
  are saved per song as LoopProfile rows (LoopProfileRepository).
- Any track change (Next, Previous, tapping another song) ends whole-song repeat
  and any section session. A saved profile is re-armed when that song loads.
  Previous that only restarts the current song (after 3 s) is a seek, not a
  track change.
- Short tap on the Loop button while a section loop is set -> Off (cancels the
  session, keeps the saved profile). Reopen the editor and Save to re-set it.
- Next on the last song stops and rewinds (does not wrap).
- Do not put a Tooltip around the Loop button (its long-press competes with ours).
- The editor test overrides loopProfileApplierProvider (no real player in tests).
- Simulator: dragging an mp3 onto it opens Messages. Workaround: run
  `python3 -m http.server 8000` in a folder with test.mp3, open
  http://localhost:8000 in simulator Safari, long-press the file, Download Linked
  File, then import from On My iPhone > Downloads.
- Keep the Simulator window open while running `flutter run`.
- Many songs have no artist tag; "Unknown Artist" is expected for those.
- `flutter analyze` may show two harmless "info" notes about angle brackets in
  doc comments (song.dart). Ignore.

## Known limitations
- Loop end is not sample-accurate: position updates arrive ~every 200 ms and the
  engine seeks back when within 200 ms of End, so the loop can end up to ~0.2 s
  early. PRD FR-028 wants ~100 ms; revisit in Phase 6/7 (not done in Phase 4; faster position stream
  only while a loop is active; verify the just_audio API first).
- Duration is 0 if tags lack it; the player shows the real duration but it is
  not written back to the database yet.
- No on-screen "remaining plays" / "loop active vs waiting" indicator (PRD FR-025).
- Lock screen does not show the repeat/loop state.
- Always-visible alternative entry point to the loop editor (PRD FR-043) not built.
- Library only has the Songs view (no Albums/Artists/Playlists/Favorites/
  Recently Played yet; PRD FR-003) and no queue view (FR-008).

## Phase 4 — waveform editor (DONE, tested on the iPhone)
- 4-1 waveform: generated with just_waveform (verified API:
  JustWaveform.extract(audioInFile: File, waveOutFile: File, zoom) ->
  Stream<WaveformProgress>; JustWaveform.parse(File) -> Future<Waveform>).
  Works for MP3, M4A and WAV. Cached on disk as waveforms/<songId>.wave
  (written as .part then renamed; deleted when the song is removed). Shown in
  the loop editor with region highlight, moving playhead, progress while
  generating, error + Retry (the time fields still work without it).
  Files: lib/data/services/waveform_service.dart,
  lib/domain/waveform/waveform_peaks.dart + waveform_loader.dart,
  lib/providers/waveform_provider.dart,
  lib/presentation/now_playing/waveform_view.dart.
  Package added: just_waveform ^0.0.7.
- 4-2 handles: green Start / red End handles on the waveform with time labels,
  +/-100 ms buttons beside each time field. Handles cannot cross (minimum gap
  100 ms) or leave 0..song length; moving one never moves the other. Dragging
  snaps to 10 ms. The text fields are the source of truth: handles and fields
  always show the same values, nothing is saved until Save, Cancel discards.
  Handles only appear while Finite or Infinite is selected.
  Files: lib/domain/loop/loop_region.dart (pure Dart clamp/snap rules),
  waveform_view.dart (StatefulWidget, onStartChanged/onEndChanged),
  loop_editor_sheet.dart.
- 4-3 Preview: button under the waveform in the loop editor ("Preview" /
  "Stop preview"). Plays the UNSAVED Start/End from the fields, starting
  EXACTLY at Start (owner asked to remove the earlier 2 s lead-in), and PAUSES
  at End (stops ~100 ms early because position updates arrive every ~200 ms).
  Rules: while previewing, the saved/armed section loop gets NO position
  events (only one thing controls playback). Preview ends on: reaching End,
  Stop button (pauses), Next/Previous/tapping another song, a seek-bar drag
  or any seek, Save (the new loop takes over), the song completing, and
  closing the editor (song keeps playing). When it ends the saved loop is told
  where the playhead is, exactly like a manual seek (re-armed if before Start,
  ended if past End). Preview moves the playhead and does not return to where
  you were. Preview never writes to the database.
  Files: lib/domain/playback/preview_session.dart (pure Dart),
  lib/domain/playback/audio_handler.dart (previewRegion, stopPreview,
  _finishPreview + one-line hooks in _endRepeat, _onPositionChanged,
  applyLoopProfile, seek, skipToPrevious restart, _onTrackCompleted),
  lib/providers/audio_handler_provider.dart (loopPreviewStartProvider,
  loopPreviewStopProvider, loopPreviewingProvider).
- Phase 4 tests: loop_region_test, waveform_view_test, preview_session_test,
  loop_editor_test (19 widget tests). The handler's preview code cannot be
  unit-tested (needs a real player): iPhone only.
- Phase 4 limitations: long-press on +/- does not auto-repeat; the very
  short-region edge case (region under ~1 s with the playhead already inside
  it) may end a preview immediately; the waveform needs a song that
  just_waveform can decode (error + Retry otherwise).

## Phase 5 — Auto Loop (IN PROGRESS)
- 5-1 analyzer: written by Claude; owner reports `flutter test` ALL PASSED (test
  count, `flutter analyze` and an app regression check not reported yet:
  <CONFIRM>). Not tuned on real songs. Pure Dart, no new package, uses the cached
  waveform (one loudness value per 10 ms). No Dart/Flutter was available when it
  was written; the algorithm was first checked with a Python prototype on
  synthetic songs.
  Files: lib/domain/autoloop/auto_loop_config.dart (styles Exact / Beat-aligned /
  Energy, AutoLoopSettings with JSON for the existing autoLoopPrefsJson column,
  ALL tuning numbers in AutoLoopTuning), auto_loop_result.dart,
  auto_loop_analyzer.dart (AutoLoopAnalyzer.analyze + top-level
  runAutoLoopAnalysis), test/auto_loop_analyzer_test.dart.
  Defaults: target 20 s, allowed 5 s to 60 s. Honest limits: loudness only (no
  pitch), beat positions are estimates, constants are NOT tuned on real music.
- 5-2 background run: WRITTEN BY CLAUDE, **NOT YET RUN OR TESTED BY OWNER**. Reads
  the cached waveform, then runs the analysis with Flutter's compute() (verified:
  `compute(topLevelFn, message)` from package:flutter/foundation.dart; no new
  package). Never writes to the database. Nothing in the UI uses it yet.
  Files: lib/domain/autoloop/auto_loop_runner.dart (AutoLoopRunner interface,
  AutoLoopStage, AutoLoopException), lib/data/services/auto_loop_service.dart,
  lib/providers/auto_loop_provider.dart (autoLoopRunnerProvider; tests override
  it with a fake), test/auto_loop_service_test.dart (includes one test that uses
  a REAL isolate).
  "Ran fine but no good loop" is a normal AutoLoopResult (found == false with a
  failure reason); AutoLoopException means a real error (song/waveform unreadable,
  analysis crashed) and its message is safe to show.
- <CONFIRM: `flutter test` and `flutter analyze` results for 5-2>
- Still to do: 5-3 Auto Loop panel in
  the loop editor (target, style, loading/success/failure/Retry, handles pre-set,
  "Replace existing loop?" confirmation, nothing saved until Save); 5-4 tuning on
  real songs from the owner's feedback.

## Tested
- Phase 4-1, 4-2, 4-3 on the iPhone: owner reports everything works.
- AFTER that, the 2 s lead-in was removed from Preview (preview_session.dart,
  its test and comments). Owner has not retested that one change yet:
  <CONFIRM: Preview starts exactly at Start>.
- <CONFIRM: any Phase 3 checks from the list above that I have not done,
  especially lock-screen / Control Centre / headphone Next during an infinite
  section loop>.
- <CONFIRM: real `flutter test` pass count and `flutter analyze` result>.

## Next steps
1. Phase 5 Auto Loop, steps 5-2..5-4 remain (see Phase 5 section) (PRD FR-033..FR-039, LoopPlayer_Plan.md Phase 5): target
   duration, candidate analysis, preview + adjustable handles (reuse the Phase 4
   editor), never overwrite a saved loop without confirmation, honest "no good
   candidate" result, loading/failure states with retry. It may need an audio
   analysis approach or package: ASK the owner before adding any package, and
   verify APIs with a web search first. Propose the plan before writing code.
2. Phase 6 polish (library views Albums/Artists/Playlists/Favorites/Recently
   Played, queue view FR-008, always-visible editor entry point FR-043, loop
   indicator with remaining plays FR-025, lock-screen loop state, tighter loop
   end timing toward ~100 ms FR-028).
3. Phase 7 regression + performance.
