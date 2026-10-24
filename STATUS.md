# LoopPlayer — Handoff Status

## About me
Complete beginner, building my first iOS app. Mac (macOS 15), Xcode 26.2,
Flutter 3.44.0 / Dart 3.12. Testing on iPhone 17 Simulator so far.
Real device: iPhone 13, iOS 26.6.1, USB-C to Lightning cable.
Project folder: ~/Developer/LoopPlayer (moved out of Desktop because iCloud
metadata caused "CodeSign failed").
I edit code in VS Code. Xcode is only for building/signing.

## How I want you to work
- Small steps; give me complete files + exact Terminal commands.
- I run the code and paste errors back. You cannot run Flutter.
- Read my actual files before changing anything. Do NOT guess at code
  that isn't in front of you; if unsure, ask me to paste the file.
- Verify package APIs with a web search before using them (versions changed).
- Do not claim a feature works until I've tested it.
- The PRD.md and LoopPlayer_Plan.md in this folder are the spec.

## Done and tested by me in the simulator
- Phase 1A: scaffold, packages, background-audio flag in Info.plist, iOS 14 target.
- Phase 1B-1: sqflite database (songs + loop_profiles tables), Song and
  LoopProfile models, DAOs, repositories, Riverpod providers.
  Unit tests pass (loop range validation, search).
- Phase 1B-2: import from Files app (file_picker -> copy into app storage ->
  read tags -> save). Multi-select import works.
- Phase 1B-3: search, remove song with confirmation dialog.
- Phase 1C-1: audio engine (LoopPlayerAudioHandler, QueueManager), tap to play,
  auto-advance, mini-player, removing the playing song stops playback.
- Phase 1C-2: Now Playing screen (artwork, seek bar, prev/play/next).
  Tapping mini-player opens it.


## Key decisions / gotchas
- metadata_god and just_waveform REMOVED (metadata_god needs Rust). Tags are
  read with audio_metadata_reader (pure Dart). Re-add a waveform package in Phase 4.
- Song.filePath / artworkPath are stored RELATIVE ("music/<id>.mp3") because iOS
  app folder paths can change. Always use song.absoluteFilePath /
  song.absoluteArtworkPath (extension in lib/core/storage_paths.dart).
- file_picker v13 API: FilePicker.pickFiles(...) is static and returns
  List<PlatformFile> (empty = cancelled). There is no FilePicker.platform.
- Riverpod 3: use .when(...) on AsyncValue (not .valueOrNull).
- The audio handler owns the AudioPlayer; UI only calls handler methods and
  watches audio_service streams. Loop logic will hook into
  _onTrackCompleted() and skipToNext() in lib/domain/playback/audio_handler.dart.
- Next on the last song stops and rewinds (does not wrap).
- Simulator: dragging an mp3 onto it opens Messages. Workaround: run
  `python3 -m http.server 8000` in a folder with test.mp3, open
  http://localhost:8000 in simulator Safari, long-press the file, Download Linked
  File, then import from On My iPhone > Downloads.
- Keep the Simulator window open while running `flutter run`.
- Many songs have no artist tag; "Unknown Artist" is expected for those.

## Known limitations
- Duration is 0 if tags lack it; the player shows the real duration but it is
  not written back to the database yet.
- Last song/position is NOT remembered after restart yet.

## NOT tested yet
- Real iPhone, background audio, lock screen / Control Centre controls,
  phone-call interruption, headphone unplug, app restart restore.

## Next steps
1. Phase 1C-3: save/restore last song + position; real-iPhone setup
   (Developer Mode, unique bundle ID instead of com.example.loopPlayer,
   free Apple ID signing); test background audio + lock screen + interruptions.
2. Phase 2: Loop button (tap cycle Off -> Repeat once -> Repeat infinite -> Off,
   long-press opens editor stub).
3. Phase 3: section loop engine + saved profiles + Next priority.
4. Phase 4 waveform editor, Phase 5 Auto Loop, Phase 6 polish, Phase 7 regression.

## Done and tested by me
- Phase 1C-3: save/restore last song + position (simulator + real iPhone, all pass).
- Phase 2: Loop button, tap cycle Off/Once/Infinite, long-press opens editor
  (real iPhone, all pass). Logic in lib/domain/loop/whole_song_repeat.dart.
- Phase 3-1: Custom Loop editor + saved per-song loop profiles
  (lib/presentation/now_playing/loop_editor_sheet.dart). STATUS: <tested>

## Key decisions / gotchas (add)
- just_audio exports its own `LoopMode`. audio_handler.dart imports it with
  `hide LoopMode` so our LoopMode (lib/domain/loop/loop_mode.dart) is the one used.
- Whole-song repeat (Once/Infinite) is NOT saved across restarts. Only section
  loops are saved profiles (LoopProfileRepository).
- Any track change (Next, Previous, tapping another song) ends whole-song repeat.
- Delivery format: complete files in a zip that unzips over the project, plus
  exact Terminal commands. I run flutter analyze / flutter test and paste results.

## Next steps
1. Phase 3-2: section loop ENGINE. Make audio follow the saved profile
   (finite N plays then continue from loop end; infinite until Next/mode change).
   Next from the app, lock screen, Control Centre, headphones must always exit
   an infinite loop (skipToNext in audio_handler.dart). Stale position events
   must be ignored. See LoopPlayer_Plan.md Phase 3 and PRD FR-014..FR-025, §13.
2. Phase 4 waveform editor, Phase 5 Auto Loop, Phase 6 polish, Phase 7 regression.