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
- Phase 4-1: zip file was downloaded and the waveform is displayed with whatever function it 
  was set to do

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
  read with audio_metadata_reader (pure Dart). Re-add a waveform package in Phase 4.
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
  early. PRD FR-028 wants ~100 ms; revisit in Phase 4 (faster position stream
  only while a loop is active; verify the just_audio API first).
- Duration is 0 if tags lack it; the player shows the real duration but it is
  not written back to the database yet.
- No on-screen "remaining plays" / "loop active vs waiting" indicator (PRD FR-025).
- Lock screen does not show the repeat/loop state.
- Always-visible alternative entry point to the loop editor (PRD FR-043) not built.
- Library only has the Songs view (no Albums/Artists/Playlists/Favorites/
  Recently Played yet; PRD FR-003) and no queue view (FR-008).

## Phase 4 — waveform editor (IN PROGRESS, split in 3 steps)
- 4-1 (written by Claude, NOT yet tested): waveform generated with the
  just_waveform package (verified API: JustWaveform.extract(audioInFile: File,
  waveOutFile: File, zoom) -> Stream<WaveformProgress>; JustWaveform.parse(File)
  -> Future<Waveform>; Waveform.getPixelMin/Max, flags, sampleRate,
  samplesPerPixel, length). Cached on disk as waveforms/<songId>.wave (written
  as .part then renamed; deleted when the song is removed). Shown inside the
  loop editor: region highlighted from the Start/End fields, moving playhead,
  progress while generating, error message + Retry (the time fields still work).
  Files: lib/data/services/waveform_service.dart,
  lib/domain/waveform/waveform_peaks.dart, waveform_loader.dart,
  lib/providers/waveform_provider.dart,
  lib/presentation/now_playing/waveform_view.dart (+ editor integration).
  Added package: just_waveform ^0.0.7 (`flutter pub add just_waveform`).
- UNVERIFIED about just_waveform: which audio formats it decodes on iOS (docs
  only show an MP3 example). Test MP3, M4A/AAC and WAV on the iPhone. If M4A
  fails, the alternative found was the `sonix` package (FFI + FFmpeg, supports
  MP3/M4A/WAV/FLAC; API: Sonix().generateWaveformInIsolate(path) -> amplitudes
  0..1); not tried.
- 4-2 (next): draggable Start/End handles with timestamps, +/-100 ms buttons,
  handles cannot cross. 4-3: Preview button (plays from 2 s before Start).

## Tested
- Phase 4-1 on the iPhone (waveform for MP3 / M4A / WAV, cache on 2nd open,
  region highlight, playhead, error + Retry).
- <CONFIRM: any Phase 3 checks from the list above that I have not done,
  especially lock-screen / Control Centre / headphone Next during an infinite
  section loop>.

## Next steps
1. Ask for owner permission and go for Phase 4-2 on the iPhone; fix anything found. Then 4-3.
3. Phase 5 Auto Loop, Phase 6 polish (library views, queue, FR-043 entry point,
   FR-025 indicator), Phase 7 regression + performance.
