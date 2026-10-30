# LoopPlayer — Handoff Status

> **NEW CHAT? Read HANDOFF.md FIRST (short). This file is long (50 KB): do NOT
> print it whole. Read only the sections HANDOFF.md names (use grep -n "^## ").**

> Lines marked **<CONFIRM>** are things only the owner can confirm. A new AI
> chat must NOT guess them. Update this file after every tested step.

## About me
Complete beginner, building my first iOS app. Mac (macOS 15), Xcode 26.2,
Flutter 3.44.0 / Dart 3.12. Tested on iPhone 17 Simulator AND a real iPhone 13
(iOS 26.6.1, USB-C to Lightning cable).
Project folder: ~/Developer/LoopPlayer (moved out of Desktop because iCloud
metadata caused "CodeSign failed"). The project is a git repo.
Git: the last good state is the Phase 4 end commit 0dfb8d5 ("final changes done
in Phase 4"). A Phase 5 commit (602747c) was made and then REMOVED by the owner
(see "Phase 5 — DROPPED"). I commit after each tested step.
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
- Phase 5 (Auto Loop): DROPPED by the owner, never shipped. See below.

## Phase 5 — DROPPED (owner's decision, do NOT build)
- Phase 5 (Auto Loop, PRD FR-033..FR-039) is intentionally NOT part of this app.
  A first version was built and then removed. The code is back to the Phase 4
  end state (a new chat that read the uploaded folder found no auto_loop files
  in lib/ or test/, no Phase 5 provider, and no pubspec change).
- Why: the owner did not want a whole-song "find the best loop" search. What
  they actually wanted is much smaller: they pick a loop themselves (for
  example 3:30 to 3:40) and the app helps by refining it to the best spot
  NEARBY (for example 3:32, because 3:30 is just random music and 3:32 is the
  real start of the part). That idea is NOT planned. If the owner ever asks for
  it, propose a small "snap to nearby" feature first, and ask before anything
  else.
- Ignore every Auto Loop mention in PRD.md / LoopPlayer_Plan.md (PRD section 8,
  the "or use Auto Loop" line in 3.2, the Auto Loop test items in 15 and the
  Auto Loop line in 18). Phase 6 is next.
- Database: the loop_profiles column auto_loop_prefs_json and the model field
  autoLoopPrefsJson were created BEFORE Phase 5 and are unused. Leave them
  alone: removing a column needs a migration, which is risk for no benefit.
- Possible cleanup (optional): if a git stash or backup of the Phase 5 work
  still exists, it can be deleted once Phase 6 is stable.

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
- Lock screen does not show the repeat/loop state (owner chose to SKIP this).
- No accessibility pass (VoiceOver labels, 44 pt targets) (owner chose to SKIP).
- Library has Songs, Playlists, Favorites, Recently Played. Albums and Artists
  were built (6-3) and then REMOVED on purpose by the owner. The queue view
  exists (6-4). The loop indicator and the "Edit loop" button exist (6-1).
- No playlist reordering, no "add to queue / play next", and "Add to playlist"
  is only in the library song menus (not on Now Playing): none were requested.

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

## Tested
- Phase 4-1, 4-2, 4-3 on the iPhone: owner reports everything works.
- AFTER that, the 2 s lead-in was removed from Preview (preview_session.dart,
  its test and comments). Owner has not retested that one change yet:
  <CONFIRM: Preview starts exactly at Start>.
- <CONFIRM: any Phase 3 checks from the list above that I have not done,
  especially lock-screen / Control Centre / headphone Next during an infinite
  section loop>.
- <CONFIRM: real `flutter test` pass count and `flutter analyze` result>.

## Facts about the code that matter for Phase 6 (read from the files)
- Database is version 1 (becomes version 2 in 6-5, see Phase 6 progress). The songs table ALREADY has last_played_at and
  is_favorite, and Song already has lastPlayedAt / isFavorite, but NOTHING
  writes them yet and no screen shows them. Favorites and Recently Played need
  no migration.
- There is no playlist table. Playlists need a database migration (version 2),
  which is the one risky change in Phase 6. Ask the owner first.
- Albums and Artists can be built by grouping the existing songs (album and
  artist fields); no database change.
- The library screen (lib/presentation/library/library_screen.dart) is one
  Songs list with search, import, remove. main.dart opens LibraryScreen
  directly.
- The queue lives in QueueManager (lib/domain/playback/queue_manager.dart,
  songs + index) inside the audio handler; there is no queue screen and the
  handler has no "jump to queue index" method yet.
- The Loop button shows A-B for section loops but no remaining-plays count, and
  nothing shows whether a saved section loop is waiting or running (FR-025).
  The section engine state is in lib/domain/loop/active_loop_session.dart and
  section_loop_engine.dart.

## Phase 6 progress
- Phase 5 is skipped on purpose. Phase 6 = steps 6-1..6-4 PLUS 6-5 playlists
  (owner said YES, do it right after 6-4). The optional extras are SKIPPED.
- 6-1 Loop indicator: DONE. Owner ran it and said everything works.
  What it does: Now Playing shows, under the Loop button, a card with the
  section range ("Loop 1:05 - 1:20"), "Waiting - starts at 1:05" or
  "Running - 3 left" / "Running - infinity", plus an always-visible
  "Edit loop" button that opens the same editor as the long press.
  How: the handler takes a read-only snapshot of the engine session
  (SectionLoopStatus) through _publishLoopStatus() after every change and
  publishes it on loopStatusStream; loopStatusProvider (a Notifier, like
  repeatModeProvider) feeds LoopStatusPanel. The engine rules are unchanged
  and nothing is written to the database. "N left" includes the play in
  progress (first play of 3 shows "3 left").
  Files: lib/domain/loop/loop_status.dart (pure Dart),
  lib/presentation/now_playing/loop_status_panel.dart,
  lib/providers/audio_handler_provider.dart (loopStatusProvider),
  lib/domain/playback/audio_handler.dart (11 small _publishLoopStatus calls),
  lib/presentation/now_playing/now_playing_screen.dart.
  Tests: test/loop_status_test.dart (drives the real engine),
  test/loop_status_panel_test.dart.
  iPhone checks to do: set a finite loop while the song is before Start ->
  card says Waiting; when playback reaches Start -> Running and the number
  counts down; infinite -> infinity sign; Next / tapping the Loop button ->
  card disappears; seek before Start -> back to Waiting; Edit loop opens the
  editor.

- OWNER DECISIONS (Phase 6): PLAYLISTS (6-5) = YES, the owner wants them.
  DO NOT FORGET. It is the only step needing a database migration (version 2),
  so it comes after 6-4, with a backup note and tests for the migration.
  Optional extras: owner said SKIP "loop state on the lock screen" and the
  "accessibility pass". Tighter loop-end timing was never asked for again:
  treat as skipped unless the owner raises it. Do not build these.
  Phase 6 now = 6-3, 6-4, then 6-5 playlists (the owner wants it done, "whenever
  you think you can": do it right after 6-4).
- 6-2 Favorites + Recently Played data: DONE. Owner ran it and said everything
  works.
  No migration: uses the existing is_favorite and last_played_at columns.
  What it does: a heart on every library row and in the Now Playing app bar
  (filled red = favorite, saved immediately). When a song starts playing the
  handler saves last_played_at (once per song load, not on every pause/resume;
  also when the user presses play on the restored paused song). Replays by
  whole-song repeat or section loops do not count again.
  How: SongDao.setFavorite / setLastPlayed update ONE column only (never the
  whole row); LibraryRepository.setFavorite / markPlayed;
  LibraryNotifier.setFavorite / refresh; handler _recordPlayed ->
  songPlayedStream -> songPlayedProvider -> LibraryScreen reloads.
  Now Playing asks songsProvider (not the queue copy, which is stale) whether
  the current song is a favorite.
  NOT visible yet: the Favorites and Recently Played LISTS come in 6-3. In 6-2
  you can only see the hearts. Recently Played is recorded but not shown.
  Files: lib/presentation/shared/favorite_button.dart (new), song_dao.dart,
  library_repository.dart, library_provider.dart, audio_handler.dart,
  audio_handler_provider.dart, library_screen.dart, now_playing_screen.dart.
  Tests: test/favorite_button_test.dart (the DB writes are not unit-tested:
  the project has no database test setup).
  iPhone checks: tap a heart in the library -> fills red; open Now Playing for
  that song -> heart is filled; un-heart it there -> library heart empties;
  close and reopen the app -> hearts are still there; play a song, pause,
  play -> no errors; a damaged file still shows its error message.
- 6-3 Library views: DONE. Owner ran it: flutter test = 162 tests, all passed,
  and said everything works on the phone.
  What it does: the Library screen has 5 tabs: Songs, Albums, Artists,
  Favorites, Recently Played. Albums and Artists are built by grouping the songs
  we already have (nothing stored, no migration). Tapping an album or artist
  opens GroupDetailScreen (its songs + "Play all" + the mini player). Tapping a
  song plays THE LIST YOU ARE LOOKING AT as the queue, starting at that song.
  The search box (shared, above the tabs) filters every tab: song tabs by
  title/artist/album; Albums/Artists keep a group if its name OR any song in
  it matches. Recently Played = songs with last_played_at, newest first, max 50
  (recentlyPlayedLimit). Favorites sorted by title. Blank or missing album /
  artist = "Unknown Album" / "Unknown Artist", always last. Album subtitle:
  "Artist - N songs" or "Various artists - N songs".
  How: lib/domain/library/library_views.dart (pure Dart: SongGroup,
  groupByAlbum/groupByArtist/groupSongs, favoriteSongs, recentlyPlayedSongs,
  filterGroups). The old private _SongTile and the remove/heart code moved out
  of library_screen.dart into shared files so every list reuses them:
  presentation/library/song_list_view.dart (SongListView + SongTile),
  song_actions.dart (confirmAndRemoveSong, setSongFavorite; they grab the
  messenger/handler/notifier BEFORE the first await so a row that disappears
  cannot break the snackbar), group_list_view.dart, group_detail_screen.dart
  (remembers only kind + key and rebuilds the group from songsProvider, so
  hearts/removals/plays update live), list_message.dart.
  Files changed: library_screen.dart (rewritten; import, search box and empty
  state kept as before). Behaviour that must NOT change: import, search, remove
  with confirmation, long-press remove, heart, red current-song title.
  Tests: test/library_views_test.dart (pure logic),
  test/group_list_view_test.dart (widget).
  iPhone checks: 5 tabs visible and swipeable; Songs tab looks and works as
  before; Albums/Artists list with counts, tap -> songs + Play all; tap a song
  inside an album -> plays and Next stays inside that album; heart a song ->
  appears in Favorites, un-heart -> disappears; play two songs -> Recently
  Played shows newest first; type in the search box on each tab; remove a song
  from inside an album (long press) -> confirmation, list updates, if it was
  the last song the screen says "No songs here."; empty Favorites / Recently
  Played show their messages.
- 6-4 Queue view (FR-008): DONE. Owner ran it and said everything works.
  What it does: a Queue icon in the Now Playing app bar (next to the heart)
  opens QueueScreen: every queued song in play order, the playing one
  highlighted in the primary colour with a "graphic_eq" icon and NO remove
  button (removing the playing song would silently stop the music). Tap any
  other song -> jumps to it and plays it. Tap the X -> removes it from the
  QUEUE only (never from the library; the queue is also saved for restore).
  The screen opens scrolled so the playing song is near the top. Empty queue
  -> "The queue is empty." message. Next/Previous continue from the song you
  jumped to.
  How: QueueManager.moveTo(index) (pure; false and no change if out of range);
  handler overrides the standard audio_service skipToQueueItem(index): same
  rules as Next (_endRepeat() first, so it cancels any loop, loads that song's
  own saved loop profile; PRD FR-022); queueProvider streams handler.queue;
  removal reuses handler.removeFromQueue. domain/playback/queue_position.dart
  has indexOfSong(ids, currentId) (pure) used to scroll.
  Files: lib/presentation/queue/queue_screen.dart (new),
  lib/domain/playback/queue_position.dart (new), queue_manager.dart,
  audio_handler.dart, audio_handler_provider.dart, now_playing_screen.dart.
  Tests: test/queue_jump_test.dart, test/queue_screen_test.dart (the actual
  tap-to-jump needs a real player and is only checked on the phone).
  iPhone checks: play a song from the library (queue = the tab you tapped
  from); open Now Playing -> Queue icon -> list shows, current highlighted;
  tap another song -> it plays, Now Playing updates, highlight moves; tap X on
  a song -> it disappears, music keeps playing; set a loop on song A, jump to
  song B from the queue -> loop of A stops, B plays normally (and B's own saved
  loop, if any, arms); the current song has no X; Next/Previous after a jump
  go to the neighbours of the new song; close and reopen the app -> queue
  still restored; library removal of a queued song still works.
- 6-5 Playlists (DATABASE VERSION 2): DONE. Owner ran it (including the
  upgrade over the existing install) and said everything works.
  MIGRATION (the risky part): _dbVersion 1 -> 2. It ONLY ADDS two tables:
    playlists(id, name, created_at) and
    playlist_songs(playlist_id -> playlists ON DELETE CASCADE,
                   song_id -> songs ON DELETE CASCADE, position, added_at,
                   PRIMARY KEY(playlist_id, song_id)) + an index.
  songs and loop_profiles are NOT touched. Fresh installs (_onCreate) and
  upgrades (_onUpgrade, only when oldVersion < 2) both call the same
  _createPlaylistTables (CREATE TABLE IF NOT EXISTS). sqflite runs onUpgrade in
  a transaction (all or nothing). Foreign keys are ON (onConfigure), so deleting
  a song or a playlist cleans its playlist_songs rows automatically.
  A song can be in a playlist ONCE (primary key); order = order added
  (position = max+1). No reordering UI (not required).
  What it does: 6th Library tab "Playlists" (after Artists): "New playlist"
  row + one row per playlist with its song count; tap -> PlaylistDetailScreen
  (songs, "Play all", menu: Rename / Delete playlist with confirmation; a song's
  menu says "Remove from playlist": no confirmation, the song stays in the
  library; long press does nothing there). Every song row in the library lists
  now has "Add to playlist..." in its menu: a bottom sheet with the playlists
  and "New playlist"; the snackbar says Added / Already in. Names: trimmed,
  1-60 chars, no duplicates ignoring case (validatePlaylistName). The search
  box filters the Playlists tab by name. Tapping a song in a playlist plays
  that playlist as the queue. Removing a song from the LIBRARY also removes it
  from playlists (LibraryNotifier.removeSong refreshes playlistsProvider).
  How: PlaylistsNotifier (AsyncNotifier<PlaylistLibrary>) loads all playlists +
  all song ids in two queries and swaps the state in one go after every change
  (no loading flash). PlaylistDetailScreen remembers only the playlist id and
  maps ids -> live Songs via songsProvider (so hearts stay fresh).
  Files: NEW lib/data/models/playlist.dart (Playlist, PlaylistLibrary),
  lib/data/database/playlist_dao.dart, lib/data/repositories/
  playlist_repository.dart, lib/domain/library/playlist_rules.dart,
  lib/providers/playlist_provider.dart, lib/presentation/playlists/
  (playlist_dialogs, playlist_actions, playlist_list_view,
  playlist_detail_screen). CHANGED app_database.dart (version 2, test hook
  AppDatabase.forTesting(path)), library_provider.dart, library_screen.dart
  (6 tabs), song_list_view.dart (playlistId, Add to playlist), pubspec.yaml.
  NEW DEV DEPENDENCY: sqflite_common_ffi ^2.4.0+2 (dev only; never shipped in
  the app) so `flutter test` can run the REAL migration on real SQLite.
  If `flutter pub get` or that test file fails on the owner's Mac only because
  of this package, the safe fallback is: delete test/playlist_database_test.dart
  and remove the sqflite_common_ffi lines from pubspec.yaml (the app itself is
  unaffected); then rely on the iPhone upgrade check.
  Tests: test/playlist_rules_test.dart, test/playlist_database_test.dart
  (fresh install = version 2 + 4 tables; upgrade from a real v1 database keeps
  songs, favorites, last played and loops; playlists usable right after the
  upgrade; reopening is harmless; order; duplicates ignored; delete playlist
  keeps songs; delete song leaves playlists), test/playlist_list_view_test.dart.
  iPhone checks (IMPORTANT, do the first one first): 1) UPGRADE: run the new
  build OVER the existing install (do NOT delete the app first): all songs,
  hearts, loops and the restored queue must still be there. 2) Playlists tab
  -> New playlist -> name it; empty name / duplicate name show a message in the
  dialog. 3) A song's menu -> Add to playlist... -> pick it; adding the same
  song again says "Already in". 4) Open the playlist: songs in the order added;
  tap a song -> plays, Next stays in the playlist; Play all. 5) Remove from
  playlist (menu) -> gone from the playlist, still in Songs. 6) Rename; Delete
  (confirm) -> songs still in the library. 7) Remove a song from the library
  that is in a playlist -> its playlist count drops. 8) Close and reopen the
  app -> playlists still there.
- ALBUMS AND ARTISTS REMOVED (owner request, after 6-5): the owner does not
  want an Albums tab or an Artists tab, "removed entirely". Deleted:
  lib/presentation/library/group_list_view.dart, group_detail_screen.dart,
  test/group_list_view_test.dart, and from lib/domain/library/library_views.dart
  everything about groups (SongGroup, groupSongs/groupByAlbum/groupByArtist,
  filterGroups); test/library_views_test.dart now tests only favoriteSongs and
  recentlyPlayedSongs. The Library now has 4 tabs: Songs, Playlists, Favorites,
  Recently Played. The 6-3 description above still mentions Albums/Artists and
  GroupDetailScreen: that part is OUT OF DATE, ignore it. Nothing else changed:
  the search box still matches a song's title, artist and album text (that is
  filterSongs, unrelated to the tabs), and Song.album / Song.artist remain in the
  database and model. Do NOT rebuild Albums/Artists unless the owner asks.
  The owner confirmed the removal works ("removed safely").
- OWNER DECISIONS after 6-5: ADD to Phase 6 as 6-6 and 6-7: (6-6) "Play next" /
  "Add to queue", (6-7) playlist reordering + "Add to playlist" on Now Playing.
  Tighter loop-end timing: owner said NO, do not do it.
- 6-6 Play next / Add to queue: DONE. Owner ran it and said everything works.
  What it does: every song row's menu (library tabs and playlists) has
  "Play next" and "Add to queue". A song can be in the queue ONCE (the queue
  screen, saved queue and removal all identify songs by id). Play next puts the
  song right after the current one; if it is already queued it is MOVED there
  (nothing if it is already next). Add to queue puts it at the end; if it is
  already queued, nothing changes and a message says so. The playing song:
  "That song is playing now." If the queue is EMPTY, both just play the song.
  A snackbar confirms ("Will play next." / "Added to the queue." / ...). The
  queue is re-saved so it survives a restart. No database change, no new
  packages.
  How: QueueManager.playNext / addToEnd return QueueAddResult (pure, in
  queue_manager.dart together with queueAddMessage); the handler's
  playSongNext / addSongToQueue publish the new queue and call saveNow();
  song_actions.dart has playNextWithMessage / addToQueueWithMessage;
  song_list_view.dart adds the two menu items (SongTile.onPlayNext /
  onAddToQueue).
  Files: lib/domain/playback/queue_manager.dart, audio_handler.dart,
  lib/presentation/library/song_actions.dart, song_list_view.dart.
  Tests: test/queue_add_test.dart (15 tests: positions, moving, duplicates,
  no current song, messages).
  iPhone checks: play a song; on another song menu -> Play next -> message; open
  Queue: it is right after the current song; press Next -> it plays. Add to
  queue on a third song -> it is at the END of the Queue screen. Repeat Play
  next on the same song -> "Already playing next."; Add to queue on a queued
  song -> "Already in the queue."; on the playing song -> "That song is
  playing now."; Play next on a song further down the queue -> it MOVES (no
  duplicate). With nothing playing, Add to queue on a song -> it just starts
  playing. Close and reopen the app -> the queue (with the added songs) is
  restored. Works from a playlist screen too.
- 6-7 Playlist reordering + "Add to playlist" on Now Playing: DONE. Owner ran
  it and said everything works. No database change (uses the existing
  playlist_songs.position column), no new packages.
  What it does: (1) Playlist screen: when the playlist has 2+ songs, a
  "Reorder songs" icon (swap_vert) in the app bar switches to reorder mode:
  each row shows a drag handle, the hint says "Drag the handles to reorder",
  Play all is hidden, tapping the check icon ("Done") goes back. A dropped row
  stays where it is (the state is updated immediately, then saved; on a save
  error the real order is reloaded and a message is shown). The order survives
  restarts; a song added later goes to the END. (2) Now Playing app bar: a
  "playlist_add" icon (before Queue and the heart) opens the same "Add to
  playlist" sheet as the library menus, for the song that is playing.
  How: moveItem<T>(items, oldIndex, newIndex) in playlist_rules.dart (pure;
  index semantics = Flutter's onReorderItem, which is the NON-deprecated
  callback in Flutter 3.44; the old onReorder is deprecated, do not use it);
  PlaylistDao.setOrder (transaction: position = index, only for songs that
  are in the playlist); PlaylistRepository.setOrder;
  PlaylistsNotifier.reorder (optimistic). PlaylistDetailScreen became a
  ConsumerStatefulWidget with a _reordering flag. Now Playing gets the live
  Song from songsProvider (also used for the heart).
  Files: lib/domain/library/playlist_rules.dart, lib/data/database/
  playlist_dao.dart, lib/data/repositories/playlist_repository.dart,
  lib/providers/playlist_provider.dart, lib/presentation/playlists/
  playlist_detail_screen.dart, lib/presentation/now_playing/
  now_playing_screen.dart.
  Tests: test/playlist_reorder_test.dart (moveItem + real SQLite order saving;
  11 tests). The drag gesture itself is only checked on the phone.
  iPhone checks: open a playlist with 3+ songs -> tap the reorder icon ->
  drag a song by its handle to another place -> it stays there -> tap the
  check -> tap Play all: the songs play in the NEW order; leave the screen,
  come back, close and reopen the app: the order is kept; add a new song to
  the playlist -> it is at the end; with a 1-song playlist there is no
  reorder icon; on Now Playing tap the playlist_add icon -> pick a playlist
  -> "Added to ..." (and "Already in ..." the second time).
- PHASE 7 RESULT: the owner completed PHASE7_CHECKLIST.md and reported "all
  passed" (memory / battery numbers were not sent to Claude).
- POLISH 1 (owner request after Phase 7): queue row alignment + live bars +
  haptics. WRITTEN, NOT YET RUN by the owner (Claude could not run Flutter).
  <CONFIRM: flutter test count / analyze / iPhone check>. No database change,
  no new packages.
  (a) Queue screen: the playing song's icon and the X buttons were different
  widths (24 vs 48) so they did not line up; both now sit in the same 48x48
  box (a test checks their centres match). The static graphic_eq icon is
  replaced by EqualizerIcon (lib/presentation/shared/equalizer_icon.dart): 4
  bars that move while the music plays, rest in a fixed pose when paused, and
  stay still if iOS "Reduce Motion" is on. Pure bar-height maths:
  equalizerBarHeights(t). QueueScreen watches playbackStateProvider for
  "playing".
  (b) Haptics: lib/core/haptics.dart, class Haptics with tick()
  (selectionClick), light() (lightImpact), medium() (mediumImpact). It never
  throws and never waits. Where each is used:
    - Playlist reorder: medium when a row is picked up, a tick each time the
      dragged row moves about one row (ESTIMATED from the finger's movement,
      because Flutter's ReorderableListView has no "passed over a row"
      callback; rows are fixed at 72 px via itemExtent for this), light on
      drop; tick when entering / leaving reorder mode.
    - Heart: light when added, tick when removed.
    - Now Playing: light on play/pause/next/previous; tick on the Loop button
      tap, medium on its long press (opens the editor), tick on "Edit loop".
    - Mini player: light on play/pause/next.
    - Queue screen: tick on jump, light on remove (X).
    - Play next / Add to queue, Add to playlist, Create playlist, Remove from
      playlist: light on success. Confirmed removal of a song from the library
      or deleting a playlist: medium.
    - Loop editor: tick on +/- 100 ms, count +/-, Preview; light on Save.
      Waveform: tick when a handle is grabbed.
  Files: NEW lib/core/haptics.dart, lib/presentation/shared/equalizer_icon.dart,
  test/haptics_test.dart, test/equalizer_icon_test.dart. CHANGED
  queue_screen.dart, playlist_detail_screen.dart, favorite_button.dart,
  now_playing_screen.dart, mini_player.dart, song_actions.dart,
  playlist_actions.dart, loop_editor_sheet.dart, waveform_view.dart,
  test/queue_screen_test.dart (now looks for EqualizerIcon, adds the alignment
  and animation tests).
  iPhone checks (haptics only work on a real iPhone, not the simulator, and
  not when the phone is on silent in some settings: check Settings > Sounds &
  Haptics > System Haptics is ON): Queue: bars and X on one vertical line; bars
  dance while playing, freeze on pause. Playlist reorder: firm tap on pick-up,
  ticks as you drag across rows, soft tap on drop. Heart, play/pause, next,
  Loop button, add to queue / playlist, editor +/- buttons all give a tap.
  If any haptic feels too strong or too often, say which one: they are
  one-line changes (swap tick/light/medium or remove the call).
- POLISH 1 (queue alignment, live bars, haptics): the owner ran it and said
  "it works".
- SHUFFLE (owner request): DONE. Owner ran it with UI-1 and said everything
  works.
  What it does: shuffle ON mixes only the songs AFTER the current one (played
  songs and the playing song stay); shuffle OFF puts the queue back in its
  original order and keeps the same song playing. Songs removed while shuffled
  stay removed; songs added meanwhile (Play next / Add to queue) go to the end
  when shuffle is turned off. While shuffle is on, starting a new list (tapping
  a song) mixes what comes after it. "Shuffle" buttons (Songs tab, playlist
  screen) play the whole list in random order and turn shuffle on. A shuffle
  toggle sits next to the Loop button on Now Playing (accent when on). The
  shuffle ON/OFF flag is NOT saved: after a restart the queue keeps the order it
  had but the toggle shows off.
  How: QueueManager.shuffleUpcoming(Random) / setShuffledQueue / restoreOrder /
  isShuffled (pure; setQueue clears the remembered order); handler:
  setShuffle / toggleShuffle / playShuffled / shuffleEnabled / shuffleStream;
  shuffleProvider (Notifier<bool>); widgets ShuffleButton (Now Playing) and
  ShufflePlayButton (shared). No database change, no new packages.
  Tests: test/shuffle_queue_test.dart (13).
  iPhone checks: Songs tab -> Shuffle: a random song plays, the Queue screen
  shows a mixed order; Now Playing shuffle toggle turns accent; toggle OFF ->
  Queue is back in library order and the same song keeps playing (no restart);
  with shuffle ON tap another song -> the songs after it are mixed; playlist
  screen -> Shuffle; Play next / Add to queue still work; Next / Previous still
  work; the Loop button and loops are unaffected.

## UI REDESIGN (Apple Music iOS 26 inspired). THE PLAN.
Source of truth: apple_music_design_profile.json (in the project root: read it
before any UI step). It is "inspired by", not a pixel copy. Dark mode only.
The owner's reference screenshots: Home with huge title + carousels + floating
glass tab bar and mini player; Now Playing (tinted background, grabber, artwork
that shrinks when paused, title row with round buttons, thin progress bar, big
bare transport glyphs); Now Playing with the queue below ("Continue Playing"
rows with drag handles and a row of pill buttons).
RULES for every UI step (from the profile and the owner):
- UI only: never change playback, the loop engine, the database or provider
  logic (the shuffle feature above is the one allowed exception, already done).
- Keep every existing behaviour and every widget Key / button text that tests
  use (loop_save_button, loop_cancel_button, loop_start_field, loop_end_field,
  loop_preview_button, loop_start_plus, 'Preview', 'Infinite', ...). Run
  flutter test after each step; fix tests only when a purely visual change
  broke them.
- No Tooltip around the Loop button (its long press competes with ours).
- No new packages without asking (use dart:ui BackdropFilter + flutter/services
  HapticFeedback; artwork colour is extracted WITHOUT a package, see UI-4).
- BackdropFilter is expensive: only on the mini player, bottom sheets and a few
  small round buttons, NEVER on every list row.
- Use song.absoluteArtworkPath / absoluteFilePath. Riverpod 3: use .when.
- Use the tokens in lib/presentation/theme/app_theme.dart (AppColors, AppText,
  AppSpacing, AppRadius): no hard-coded colours or sizes in screens.
- Flutter 3.44 theme class names: DialogThemeData, CardThemeData,
  TabBarThemeData, AppBarThemeData, InputDecorationThemeData (NOT the old
  *Theme names).
DECISIONS made with the owner (they override the profile where they differ):
- Shuffle IS built (the profile said "no shuffle").
- Apple Music buttons we do not have (crossfade / smooth transition, "continue
  playing / infinite autoplay", lyrics, AirPlay, volume slider) are NOT built.
  Where Apple has a row of pill buttons (Now Playing / Queue) we use OUR
  features instead: Shuffle, Loop (the repeat-mode button), Edit loop (section
  loop editor), Add to playlist.
- No bottom tab bar (profile). The Library uses a row of pill chips for its REAL
  sections: Songs, Playlists, Favorites, Recently Played (Albums and Artists
  were removed by the owner).
- No Home / New / Radio / profile avatar / streaming.
- VOLUME SLIDER (owner request, DO NOT FORGET): the owner wants the volume
  slider (speaker-low icon, slider, speaker-high icon) back, as Apple Music's
  Now Playing has. Build it in UI-4 (Now Playing). just_audio's
  player.setVolume(0..1) changes only the APP's volume relative to the phone's
  volume; the phone's real (system) volume needs a NEW PACKAGE (for example
  volume_controller), so ASK the owner before adding one. Default plan: app
  volume via handler.setVolume + a provider (+ remember it), no package, and
  tell the owner the difference. The profile's old "no volume" rule is
  overridden by the owner.
PHASES (one per zip; the owner tests each before the next):
- UI-1 DONE (owner tested: works): theme file (colours, text styles, radii,
  component themes: app bar, dialogs, sheets, snackbars, menus, text fields,
  search bar, slider, buttons) applied in main.dart (dark only);
  GlassContainer, CircleIconButton. Files: lib/presentation/theme/app_theme.dart,
  lib/presentation/shared/glass_container.dart, circle_icon_button.dart,
  shuffle_play_button.dart, lib/presentation/now_playing/shuffle_button.dart,
  main.dart. Tests: test/ui_foundation_test.dart (13). The app should now be
  black with red accents and look "sane" everywhere, with the old layouts.
- UI-2 DONE (owner tested: works). What it does: the mini player is now a floating glass pill (GlassContainer,
  60 pt tall, radius 30, 12 pt side margins, 8 pt above the bottom safe area,
  soft shadow) with 40 pt artwork (radius 8), title 15 semibold, artist 13
  secondary, bare play/pause and next icons. The thin progress line was removed
  (Apple has none). Tap artwork/title -> Now Playing (GestureDetector, no
  ripple). Nothing is drawn when no song is loaded. Screens that show it
  (library_screen, playlist_detail_screen) now use Scaffold(extendBody: true) so
  lists scroll UNDER the glass and Flutter automatically pads the last row
  clear of the pill (the body's MediaQuery bottom padding becomes the height of
  the bottomNavigationBar). Playlist reorder list passes that padding
  explicitly. The mini player reads the audio handler only inside button
  callbacks (so it can be tested). RULE for any new screen with a list + mini
  player: extendBody: true + bottomNavigationBar: const MiniPlayer().
  Files: lib/presentation/shared/mini_player.dart (rewritten),
  library_screen.dart, playlist_detail_screen.dart. Tests:
  test/mini_player_test.dart (7: hidden without a song, 60 pt pill with 12 pt
  margins, title/artist/Unknown Artist, Play vs Pause, last list row stays
  clear of the pill, full height without a song).
  iPhone checks: play a song -> a floating rounded glass pill hovers above the
  bottom edge with a gap on both sides and below; rows scroll under it
  (blurred) and the LAST row can be scrolled fully above it; play/pause and next
  work; tapping the artwork/title opens Now Playing; no pill when nothing is
  loaded and the last row then clears the home indicator; same on a playlist
  screen, also in reorder mode; snackbars still show above the pill.
- UI-3 DONE (owner tested: "looks good"). No database change,
  no new packages, no behaviour change (providers, search, import, remove,
  hearts, queue actions, playlist actions all untouched).
  What it does: LIBRARY screen: no AppBar any more; a large "Library" title
  (34 pt bold) with a glass "+" import button (CircleIconButton, accent icon,
  tooltip 'Import music'); the search field (40 pt, radius 12, same shared
  search provider, same hint); a PillChipRow (Songs, Playlists, Favorites,
  Recently Played) that follows the swipe between pages (it listens to the
  TabController animation) and moves the pages when tapped (animateTo); the
  selected chip scrolls into view. Same four TabBarView pages, "Shuffle" pill
  still above the Songs list. AnnotatedRegion keeps the status bar icons light.
  SONG ROW (SongTile): 64 pt, 48 pt artwork (radius 6), title 17 medium,
  subtitle 15 secondary, then duration, a small grey heart (red when on,
  FavoriteButton(compact: true)) and a "..." menu (same items as before).
  Current song: accent title + dark veil with the EqualizerIcon bars over its
  artwork (they move only while playing). Inset hairline separators (indent
  76). SongListView got an optional header (scrolls with the rows), emptyIcon,
  and watches play/pause with select() so lists do not rebuild on every state
  update. ListMessage: first line bold 20, rest 15 secondary, optional icon.
  New EmptyState widget (64 pt icon, bold title, text, accent button) used for
  an empty library. PLAYLISTS tab: rows with the artwork of the playlist's
  first song, name, "N songs", chevron; "New playlist" row in accent.
  PLAYLIST SCREEN: the AppBar title is gone (the name is in the header); the
  list starts with a header: 200 pt artwork (radius 12, soft shadow), name 22
  bold, "N songs", then "Play all" (accent) and "Shuffle" pills. The reorder
  icon and the Rename / Delete menu stay in the app bar. Reorder mode shows only
  the hint + drag list (no header) with the same haptics as before.
  Files: NEW lib/presentation/shared/pill_chip_row.dart, empty_state.dart.
  CHANGED lib/presentation/library/library_screen.dart (rewritten, _import and
  _snack kept), song_list_view.dart, list_message.dart,
  lib/presentation/shared/favorite_button.dart (compact option; heart red is
  now AppColors.favoriteOn), lib/presentation/playlists/playlist_list_view.dart
  (allSongs param, optional), playlist_detail_screen.dart.
  Tests: NEW test/pill_chip_row_test.dart (5), test/library_widgets_test.dart
  (15: SongTile, compact heart, EmptyState, ListMessage). The existing
  playlist / queue / favorite tests were kept and should still pass.
  iPhone checks: big "Library" title with a glass + button; search under it;
  4 pill chips, the selected one light with black text; swipe the pages ->
  the chip follows (and scrolls into view for Recently Played); tap a chip ->
  the page changes; rows: 48 pt artwork, duration, small grey heart, "..."
  menu; the playing song has a red title and moving bars on its artwork (bars
  freeze on pause); inset hairlines; empty tabs show an icon + title + text;
  empty library shows the icon + 'Import music' button; Playlists tab: artwork
  thumbnails; open a playlist -> big artwork, name, count, Play all + Shuffle,
  songs below, scrolls as one page; reorder mode still works; last rows scroll
  above the floating mini player; play/shuffle/queue actions all still work.
- UI-4: Now Playing: artwork-tinted gradient background (dart:ui average colour
  of a 16x16 artwork, HSL clamp, cached per song id, fallback gradient), grabber,
  artwork scaling to 0.86 when paused, title row with glass heart, ProgressBar
  (6 pt, grows while dragging; existing seek logic unchanged), bare transport
  glyphs, loop status capsule (glass) with 'Edit loop' pill, bottom row of glass
  circles: Shuffle, Loop button (same widget, same tap/long press), Add to
  playlist, Queue. Keep a way to close (down chevron / swipe down).
- UI-5: Queue screen: same tinted background, header (56 pt artwork, title,
  artist, heart), our pill row (Shuffle, Loop, Edit loop, Add to playlist),
  "Up Next" section header, SongRow-style rows (current = accent + equalizer, no
  X; others keep the small X), same tap-to-jump.
- UI-6: Loop editor sheet + waveform container (rounded, accent region, keep
  green/red handles and all Keys), pill segmented mode selector, filled time
  fields, glass +/- buttons, accent Save, dialogs, final polish and a full
  regression pass (PHASE7_CHECKLIST.md again).

## Next steps
1. UI-4 and UI-5 DONE (owner-tested). NEXT: UI-6 (loop editor sheet + final
   polish), then UI-7 (Edit song: rename + cover from Photos), ONE phase per
   zip, updating STATUS.md AND HANDOFF.md each time.
2. Skipped by the owner, do NOT build unless asked: tighter loop-end timing,
   lock-screen loop state, accessibility pass, Auto Loop (Phase 5),
   Albums/Artists tabs, crossfade / continue-playing / lyrics / AirPlay.
   (Volume is NOT skipped: see the UI decisions.)
   Still optional if asked: write a missing song duration back to the database.

## UI-4 (DONE: owner tested on iPhone, "everything works")
Owner's `flutter test` total before UI-4: 278+ (all passed).
- New: presentation/now_playing/artwork_tint.dart (16x16 dart:ui average ->
  dark HSL tint, cached per file path, null on any error),
  now_playing_background.dart (artworkTintProvider + animated gradient, fallback
  gradient), volume_slider.dart; presentation/shared/scrub_bar.dart (6 pt bar,
  10 pt while dragging, no LayoutBuilder so it works inside IntrinsicHeight).
- Rewritten: now_playing_screen.dart (grabber to close, artwork scales 0.86x
  when paused, title row + glass heart, ScrubBar seek with the old drag logic,
  bare rewind/play/forward glyphs, glass loop capsule, volume bar, bottom glass
  row: Shuffle, Loop, Add to playlist, Queue). Restyled: loop_button.dart (glass
  circle, accent when active), loop_status_panel.dart (glass capsule + "Edit
  loop" pill; same texts), circle_icon_button.dart (new activeColor).
- Volume = the APP volume (just_audio setVolume, 0..1, relative to the phone's
  volume buttons). audio_handler.dart: volume, volumeStream, setVolume(v,
  {save}); saved via PlaybackPersistence.saveVolume/loadVolume (key
  player_volume_v1) and restored first in restoreLastSession. volumeProvider.
  Changing the SYSTEM volume would need a new package: not done, ask first.
- Fix after first run: ScrubBar now takes semanticFormat (Flutter needs value,
  increasedValue, decreasedValue together); scrub test pumps twice for the
  animation; two unnecessary imports removed. Test total was 288 passed + 3 failed.
- New tests: artwork_tint_test, scrub_bar_test, volume_slider_test,
  now_playing_background_test. Existing loop_button / loop_status_panel tests
  were left unchanged (the same texts and icons are still there).
- Known risk: IntrinsicHeight + Spacers on Now Playing, the artwork tint
  quality, and the drag feel of ScrubBar are unverified on a device.
- Tint cache is per path: UI-7 must save a new cover under a NEW file name.

## UI-7 (planned, requested by the owner): Edit song
- Edit the song NAME (title) and the COVER (pick from the iPhone Photos app).
- Needs, and must be ASKED FIRST: the image_picker package (NEW package) and
  the Info.plist key NSPhotoLibraryUsageDescription.
- Needs a database change: song title override and artwork path update in
  SongDao / Song model (check the schema version and migrations first).
- UI: an "Edit" action in the song's row menu and on Now Playing; a dialog
  with a text field and a "Change cover" button; copy the picked image into the
  app's artwork folder under a new file name; update the queue's MediaItem so
  Now Playing / mini player refresh. Add tests for the title rules.

## UI-5 (DONE: owner tested, "everything works"): Queue screen
- Rewritten: presentation/queue/queue_screen.dart. Transparent AppBar titled
  "Queue" over the same artwork-tinted background as Now Playing
  (NowPlayingBackground). Header: 56 pt artwork, title, artist, glass heart.
  Pill row (scrolls sideways): Shuffle, Loop (cycles repeat mode), Edit loop
  (opens the loop editor), Add to playlist. "Up Next" 22 pt title. Rows: 64 pt,
  48 pt artwork, accent title for the playing song, EqualizerIcon or small
  tertiary X in the same 48x48 box (alignment kept), tap-to-jump kept.
- The queue screen now watches songsProvider, shuffleProvider and
  repeatModeProvider, so test/queue_screen_test.dart overrides them with fakes.
  Test changes: the playing song and "Unknown Artist" now appear twice (header +
  row), new checks for "Up Next" and the 4 pills. No other test uses QueueScreen.
- No database change, no new package. Not changed: audio handler.
- Fix after the first test run (UI-5b): the queue screen must NOT call
  ref.read(audioHandlerProvider) inside build(); tests have no real handler and
  it threw. Read the handler only inside tap callbacks. Same rule for any new
  screen that tests pump without a handler override.
- Owner's last `flutter test`: all passing after UI-5b (exact total not
  reported; was 288 + new queue tests).
