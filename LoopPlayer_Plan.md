# LoopPlayer — Revised Implementation Plan

> [!IMPORTANT]
> **No application code has been written or modified.** This is the plan for your approval.

---

## Quick Navigation

1. [PRD.md Conversion](#1-prdmd-conversion)
2. [Full Plan Summary](#2-full-plan-summary)
3. [audio_service Architecture: Isolate Question](#3-audio_service-architecture-isolate-question)
4. [State Interaction Matrix](#4-state-interaction-matrix)
5. [Next-Command Routing](#5-next-command-routing)
6. [Verified Package Versions](#6-verified-package-versions)
7. [Phased Plan with Acceptance Tests](#7-phased-plan-with-acceptance-tests)
8. [Assumptions and Honest Limitations](#8-assumptions-and-honest-limitations)

---

## 1. PRD.md Conversion

✅ **Done.** `PRD.md` has been written to the project root at [`/Users/uniquema/Desktop/LoopPlayer/PRD.md`](file:///Users/uniquema/Desktop/LoopPlayer/PRD.md).

The file is a complete, faithful Markdown conversion of `PRD.md.rtf` (version 1.2). Every section, functional requirement (FR-001 through FR-045), priority rule, acceptance criterion, milestone, and agent instruction is preserved verbatim in formatted Markdown. The original `.rtf` file is untouched.

---

## 2. Full Plan Summary

### 2.1 Proposed Folder Structure

```
lib/
├── main.dart                          # Entry point: AudioService.init, runApp
├── app.dart                           # MaterialApp, routing, shell
│
├── data/
│   ├── database/
│   │   ├── app_database.dart          # sqflite setup, version, migrations
│   │   ├── song_dao.dart              # CRUD: songs table
│   │   └── loop_profile_dao.dart      # CRUD: loop_profiles table
│   ├── models/
│   │   ├── song.dart                  # Immutable data class; fromMap/toMap
│   │   └── loop_profile.dart          # Saved (persisted) loop config per song
│   └── repositories/
│       ├── library_repository.dart    # Import, delete, query songs
│       └── loop_profile_repository.dart  # Save/load per-song loop profiles
│
├── domain/
│   ├── loop/
│   │   ├── loop_mode.dart             # Enum: off / repeatOnce / repeatInfinite /
│   │   │                              #       finiteSection / infiniteSection
│   │   ├── active_loop_session.dart   # Transient runtime state only (never persisted)
│   │   └── loop_controller.dart       # Single authority; subscribes to positionStream;
│   │                                  # called by AudioHandler for all transitions
│   └── playback/
│       ├── audio_handler.dart         # BaseAudioHandler subclass; owns AudioPlayer
│       └── queue_manager.dart         # Track list, current index, Previous/Next logic
│
├── presentation/
│   ├── now_playing/
│   │   ├── now_playing_screen.dart
│   │   ├── loop_button.dart           # GestureDetector; tap cycle + long-press guard
│   │   └── seek_bar.dart
│   ├── loop_editor/
│   │   ├── loop_editor_sheet.dart     # Modal sheet: Off / Finite / Infinite tabs
│   │   ├── waveform_editor.dart       # Waveform + draggable handles (Phase 4)
│   │   └── auto_loop_panel.dart       # Auto Loop UI (Phase 5)
│   ├── library/
│   │   ├── library_screen.dart        # Tab host
│   │   ├── songs_tab.dart
│   │   ├── albums_tab.dart
│   │   ├── artists_tab.dart
│   │   ├── playlists_tab.dart
│   │   ├── recently_played_tab.dart
│   │   └── favorites_tab.dart
│   └── shared/
│       ├── mini_player.dart
│       └── artwork_widget.dart
│
└── providers/                         # Riverpod providers
    ├── audio_handler_provider.dart    # Exposes the AudioHandler singleton
    ├── playback_state_provider.dart   # Stream from handler.playbackState
    ├── queue_provider.dart
    ├── loop_provider.dart             # Exposes LoopController state
    └── library_provider.dart
```

### 2.2 Data Models

**`Song` (persisted)**

| Field | Type | Notes |
|---|---|---|
| `id` | `String` (UUID) | Primary key |
| `title` | `String` | From metadata; filename fallback |
| `artist` | `String?` | Nullable |
| `album` | `String?` | Nullable |
| `durationMs` | `int` | Milliseconds |
| `artworkPath` | `String?` | Path to extracted artwork file |
| `filePath` | `String` | App-managed path (copied on import) |
| `importedAt` | `int` | Unix timestamp ms |
| `lastPlayedAt` | `int?` | Updated on play |
| `isFavorite` | `bool` | Default false |

**`LoopProfile` (persisted, per song)**

| Field | Type | Notes |
|---|---|---|
| `songId` | `String` | Foreign key |
| `mode` | `LoopMode` | off / repeatOnce / repeatInfinite / finiteSection / infiniteSection |
| `loopStartMs` | `int?` | Null when mode is off/whole-song |
| `loopEndMs` | `int?` | Null when mode is off/whole-song |
| `finiteCount` | `int?` | Only for finiteSection |
| `autoLoopPrefsJson` | `String?` | Serialized Auto Loop preferences |
| `updatedAt` | `int` | Unix timestamp ms |

**`ActiveLoopSession` (in-memory, never written to DB)**

| Field | Type | Notes |
|---|---|---|
| `profile` | `LoopProfile` | Snapshot at session start |
| `iterationsCompleted` | `int` | Incremented only on confirmed iteration |
| `isCompleted` | `bool` | True after finite loop exhausted |
| `seekPending` | `bool` | Guard against stale position events |
| `trackGenerationId` | `int` | Incremented on every track load; stale callbacks are dropped |

### 2.3 Packages

See [Section 6](#6-verified-package-versions) for confirmed versions and compatibility.

### 2.4 Architecture Summary

- `AudioHandler` is the **single owner** of the `AudioPlayer` instance.
- `LoopController` runs inside `AudioHandler` — same object, same memory space.
- The UI communicates with `AudioHandler` only via the `audio_service` public interface (`handler.play()`, `handler.skipToNext()`, etc.).
- Riverpod providers expose streams from `handler.playbackState` and `loopController.stateStream` to the widget tree.
- No widget ever instantiates or directly calls `AudioPlayer`.

---

## 3. audio_service Architecture: Isolate Question

### 3.1 What I Originally Claimed (Incorrect)

The first plan stated: *"The loop controller must live inside the AudioHandler (in the service isolate)"* and warned about background stream throttling requiring isolate placement.

### 3.2 Verified Reality (audio_service ≥ v0.18.0)

> [!NOTE]
> This was verified against the `audio_service` package internals, public documentation, and community sources.

**There is no separate Dart isolate in audio_service ≥ v0.18.0.**

The pre-v0.18 architecture required you to explicitly spawn a background isolate with `AudioServiceBackground.run()`. That design was completely replaced in v0.18.0 (released ~2022). The current `0.18.x` versions (latest: `0.18.18`) use a **single-isolate model**:

| Question | Answer |
|---|---|
| Separate background Dart isolate? | **No.** |
| Where does `BaseAudioHandler` run? | **Main Dart isolate** (same as `runApp`). |
| How does iOS keep the app alive in the background? | **OS-level `UIBackgroundModes → audio` capability.** iOS does not suspend the process while an `AVAudioSession` is actively playing audio. |
| How are lock screen / Control Centre controls delivered? | Native `MPRemoteCommandCenter` → platform channel → **callback into the main Dart isolate** → `handler.skipToNext()` etc. |
| Does `just_audio`'s `positionStream` fire in the background? | **Yes.** Because the main isolate stays alive, `positionStream` continues emitting. |

### 3.3 Revised Architecture Consequence

**The original "loop engine must live in a service isolate" concern is invalid for this stack.** The `LoopController` can live directly inside the `AudioHandler` class (in the main isolate), which is the simplest correct approach:

- `LoopController` subscribes to `_player.positionStream` inside the `AudioHandler` constructor.
- When the app is backgrounded, the main isolate remains alive → `positionStream` keeps firing → `LoopController` keeps managing seek-back correctly.
- No isolate boundary, no `SendPort`/`ReceivePort`, no added complexity.

### 3.4 Remaining Real Risk: UI Widget Listeners in the Background

What *does* happen in the background is that **UI widget listeners subscribed directly to `positionStream`** fire uselessly (wasted CPU). The mitigation is:

- UI widgets must listen to `audio_service`'s `playbackState` stream (not raw `positionStream`).
- `LoopController` (inside `AudioHandler`) is the only direct subscriber to `positionStream`.
- This is the architecture described above, so no extra work is needed — it's already the correct design.

---

## 4. State Interaction Matrix

### 4.1 Loop Mode Definitions

| Mode | Abbrev | Description |
|---|---|---|
| Off | `OFF` | Normal playback; no repeat |
| Repeat Once | `R1` | Finish current → replay whole song once → advance queue |
| Repeat Infinite | `RI` | Repeat whole song forever until Next or mode change |
| Finite Section | `FS` | Repeat [start, end] N times → continue from end |
| Infinite Section | `IS` | Repeat [start, end] forever; only Next exits |

### 4.2 Interaction Table

| Event | `OFF` | `R1` | `RI` | `FS` | `IS` |
|---|---|---|---|---|---|
| **Track ends naturally** | Advance queue | Replay once, then advance queue | Seek to 0, replay | Seek to loopEnd, advance queue | Never reaches end (loop always seeks back) |
| **Reach loopEnd boundary** | N/A | N/A | N/A | Seek to loopStart; increment counter. When counter == finiteCount → exit to loopEnd, cancel session | Seek to loopStart unconditionally |
| **Short-tap Loop button** | → `R1` | → `RI` | → `OFF` | → `OFF` (cancel active session; keep saved profile) | → `OFF` (cancel active session; keep saved profile) |
| **Long-press Loop button** | Open editor | Open editor | Open editor | Open editor (pre-load saved profile) | Open editor (pre-load saved profile) |
| **Manual seek within loop region** | N/A | N/A | N/A | Reset `seekPending = true`; do not increment counter for this iteration | Reset `seekPending = true`; continue looping normally |
| **Manual seek outside loop region** | N/A | N/A | N/A | Deactivate loop session; resume as `OFF` from seek position | Same: deactivate loop session |
| **Next (any source)** | Advance queue | Advance queue | Advance queue | **Cancel active session → advance queue → load next track's profile** | **Cancel active session → advance queue → load next track's profile** |
| **Previous** | Go to previous track | Go to previous track (exit R1) | Go to previous track (exit RI) | Cancel active session → go to previous track → load that track's profile | Same |
| **Pause** | Pause | Pause (counter paused) | Pause | Pause (counter paused; session preserved in memory) | Pause (session preserved) |
| **Resume after pause** | Resume | Resume | Resume | Resume; loop session restores; `seekPending = false` | Resume; loop continues from position |
| **App backgrounded** | Continues | Continues | Continues | Loop engine continues (main isolate stays alive) | Loop engine continues |
| **App restart** | Load last-played track at last position | Load track; `LoopProfile.mode` from DB | Load track; `LoopProfile.mode` from DB | Load track; restore saved `FS` profile (start a new session when playback resumes) | Load track; restore saved `IS` profile (start new session when playback resumes) |
| **Track switch (queue advance)** | Load next; `LoopProfile` from DB | Load next; exit R1; load new profile | Load next; exit RI; load new profile | **Immediately cancel active session** (stale callbacks dropped via `trackGenerationId`) → load new track's profile | Same |
| **Audio interruption (call, other app)** | Pause; resume on interruption end if appropriate | Pause; state preserved | Pause; state preserved | Pause; session state preserved in memory | Pause; session state preserved in memory |
| **Headphone disconnect** | Pause (iOS default AVAudioSession behavior) | Same | Same | Same | Same |
| **Editor: Save** | Mode stays OFF or changes | Only section modes apply | Only section modes apply | Saves new `FS` profile to DB; applies immediately to active session | Saves new `IS` profile to DB; applies immediately |
| **Editor: Cancel** | No change | No change | No change | Restores pre-open snapshot; no DB write | Same |

### 4.3 Priority Rules (from PRD §13)

1. **Explicit Next always wins** — overrides all loop modes and pending transitions.
2. A **saved profile** does not force active looping when another track is playing.
3. **Only one mode** controls playback at a time; entering a new mode cancels the previous.
4. Whole-song repeat and section looping are **mutually exclusive**.
5. Finite counter increments only on **confirmed complete iteration** (not on seek events).
6. Infinite section loops have **no automatic exit** based on count.
7. **Track switches** cancel all stale callbacks via `trackGenerationId`.
8. Manual seeking and mode changes **always leave the player in a valid state**.

---

## 5. Next-Command Routing

### 5.1 The Single Entry Point

All Next commands — regardless of source — are routed to exactly one method:

```
AudioHandler.skipToNext()
```

This method is declared in `BaseAudioHandler` and overridden in the app's `AudioHandler` subclass. Because all command sources go through this method, loop cancellation only needs to be implemented once.

### 5.2 Verified Command Sources and Routing

| Source | How it reaches `skipToNext()` |
|---|---|
| In-app Next button | Widget calls `handler.skipToNext()` directly via the Riverpod provider |
| Lock screen Next (iOS) | `MPRemoteCommandCenter.nextTrackCommand` → platform channel → `handler.skipToNext()` |
| Control Centre Next | Same as lock screen (`MPRemoteCommandCenter`) → `handler.skipToNext()` |
| AirPods / wired headphones double-tap | iOS routes to `MPRemoteCommandCenter.nextTrackCommand` → `handler.skipToNext()` |
| CarPlay Next | Same `MPRemoteCommandCenter` routing → `handler.skipToNext()` |

**Key verified fact:** `audio_service` registers with `MPRemoteCommandCenter` automatically when `MediaControl.skipToNext` is included in the `playbackState.controls` list. All remote sources use the same native command — there is no separate code path per hardware source.

### 5.3 Implementation Pattern

```dart
@override
Future<void> skipToNext() async {
  // Step 1: Cancel loop — synchronously, before any await
  _loopController.cancelSession();
  // Step 2: Advance queue
  await _queueManager.advanceToNext();
  // Step 3: Load the next track's saved profile
  final nextProfile = await _loopProfileRepo.getProfile(_queueManager.currentSong.id);
  _loopController.loadProfile(nextProfile);
  // Step 4: Notify audio_service (updates lock screen metadata)
  mediaItem.add(/* next track MediaItem */);
}
```

### 5.4 Limitation / Open Question

> [!WARNING]
> **Headphone behavior is hardware/firmware-dependent and must be tested on a real device.**
> Not all headphones implement the double-tap-for-Next convention. AirPods Pro and standard AirPods (gen 2+) support it. Older Bluetooth headphones may only send Play/Pause. The implementation correctly routes whatever commands iOS delivers, but we cannot guarantee which headphone models support Next.

---

## 6. Verified Package Versions

> [!NOTE]
> Versions verified via pub.dev and package documentation searches. The Flutter project's `pubspec.yaml` currently requires `sdk: ^3.12.0`. All packages below require Flutter ≥ 3.27.0 for their latest versions. **This means upgrading the Flutter SDK is required before adding these packages.** Alternatively, we can pin to older-but-compatible versions as noted.

### 6.1 Version Table

| Package | Recommended version | Min Flutter | Min iOS | Key notes |
|---|---|---|---|---|
| `just_audio` | `^0.10.5` | 3.27.0 | 12.0 (13+ recommended) | AVFoundation backend; `positionStream` works in background when `audio_service` is active |
| `audio_service` | `^0.18.18` | 3.27.0 | 12.0+ | **No separate isolate** since v0.18.0; single-isolate model |
| `audio_session` | `^0.2.4` | 3.27.0 | 12.0+ | Breaking change in 0.2.0: microphone off by default; must configure `.music()` mode |
| `file_picker` | `^13.0.0` | Dart 3 | **14.0** | Uses `PHPickerViewController`; no special `Info.plist` needed for document picking |
| `sqflite` | `^2.4.5` | 3.12+ | Any | No iOS limitations |
| `path_provider` | `^2.1.6` | Dart 3 | Any | No permissions needed |
| `metadata_god` | `^1.1.0` | Dart 3 | Any | **⚠️ Requires Rust toolchain installed on build machine** |
| `just_waveform` | `^0.0.7` | 3.27.0 | Any | Same author as `just_audio`; no special permissions |
| `flutter_riverpod` | `^3.4.3` | Dart 3 | N/A | Pure Dart; no iOS constraints |

### 6.2 Critical Compatibility Issues

**Issue 1: Flutter SDK version**
The project's current `pubspec.yaml` specifies `sdk: ^3.12.0`. The latest versions of `just_audio`, `audio_service`, `audio_session`, and `just_waveform` all require Flutter ≥ 3.27.0. **Before adding packages, the Flutter SDK must be updated.**

**Action required:** Confirm you have Flutter 3.27.0+ installed (`flutter --version`). If not, update Flutter first.

**Issue 2: `metadata_god` requires Rust**
`metadata_god` v1.x uses `flutter_rust_bridge` + `cargokit`. The build machine must have the Rust toolchain (`rustup`) installed and the `aarch64-apple-ios` target added for iOS builds. This adds build complexity.

**Alternative:** If avoiding Rust dependency is preferred, we can use `flutter_media_metadata` for the first phases (read-only metadata; less reliable, Dart 2 era) or `on_audio_query` (queries the iOS media library, but limited to files indexed by iOS). I recommend accepting the Rust requirement for `metadata_god` — it's well-maintained and handles M4A and MP3 correctly.

**Issue 3: `file_picker` minimum iOS 14.0**
`file_picker` v13.x sets iOS 14.0 as the minimum deployment target. The project's current iOS deployment target should be checked and updated to 14.0 if needed (it is likely already 12.0 or 13.0 from the default Flutter scaffold).

### 6.3 iOS `Info.plist` Requirements

```xml
<!-- Mandatory: background audio -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

No other keys are required for this app's use case (local file playback only, no HTTP streaming, no microphone).

---

## 7. Phased Plan with Acceptance Tests

Each phase ends with **explicit acceptance tests** that must pass before the next phase begins.

---

### Phase 1A — SDK Update and Project Scaffold
**Goal:** Build environment confirmed; clean project shell compiles and runs on a simulator.

**Work:**
- Verify Flutter SDK version; update to ≥ 3.27.0 if needed.
- Update `pubspec.yaml`: Dart SDK to `^3.6.0`, Flutter SDK to `>=3.27.0`.
- Update iOS deployment target to 14.0 in `ios/Podfile` and `ios/Runner.xcodeproj`.
- Add `UIBackgroundModes → audio` to `ios/Runner/Info.plist`.
- Add all packages to `pubspec.yaml` (do not implement anything yet).
- Run `flutter pub get`; resolve any version conflicts.
- Replace boilerplate `main.dart` with a shell that initializes `AudioService` and calls `runApp`.

**Acceptance tests:**
- [ ] `flutter build ios --simulator` succeeds with no errors.
- [ ] App launches on iOS Simulator; shows a blank shell screen.
- [ ] `flutter pub deps` shows no version conflicts.
- [ ] `Info.plist` contains `UIBackgroundModes → audio`.
- [ ] iOS deployment target is 14.0 in both `Podfile` and Xcode project.

---

### Phase 1B — Database, Import, and Library
**Goal:** User can import an audio file and see it listed. No playback yet.

**Work:**
- Implement `app_database.dart`: sqflite setup, songs and loop_profiles tables, migration version.
- Implement `Song` model, `SongDao`, `LibraryRepository`.
- Implement `LoopProfile` model, `LoopProfileDao`, `LoopProfileRepository`.
- Implement file import: `file_picker` → copy to `applicationDocumentsDirectory` → extract metadata with `metadata_god` → save to DB.
- Implement Library screen: Songs tab with title/artist list; empty state; error state for failed import.
- Implement search (local filter on in-memory list; no full-text search yet).
- Implement song deletion with confirmation dialog.

**Acceptance tests:**
- [ ] Tap Import; iOS Files picker opens; select an MP3 → song appears in library list.
- [ ] Imported file is physically present in the app documents directory.
- [ ] Title, artist, and artwork display correctly for a tagged file.
- [ ] Title and duration display with filename fallback for an untagged file.
- [ ] Importing an unsupported file type shows an error message (not a crash).
- [ ] Deleting a song shows a confirmation dialog; after confirm, song is removed from list and file is deleted.
- [ ] Search filters list correctly.
- [ ] Library persists after app restart (kill + reopen).

---

### Phase 1C — Audio Playback and Now Playing
**Goal:** Tapping a song plays it. Basic playback controls work.

**Work:**
- Implement `AudioHandler`: instantiate `AudioPlayer`, map `playbackEventStream` to `playbackState`, implement `play()`, `pause()`, `seek()`, `stop()`.
- Implement `QueueManager`: track list, current index, `advanceToNext()`, `retreatToPrevious()`.
- Configure `audio_session` with `.music()` mode.
- Implement Now Playing screen: artwork, title, artist, seek bar (elapsed / total), Play/Pause, Previous, Next.
- Implement Mini-player: persistent bottom bar showing current track while navigating library.
- Implement `playbackState` persistence: save last-played song ID and position to shared prefs on pause/background; restore on launch.
- Implement audio interruption handling: pause on `BeganInterruption`, optionally resume on `EndedInterruption` with `shouldResume == true`.

**Acceptance tests:**
- [ ] Tap song in library → Now Playing opens → audio plays.
- [ ] Play/Pause toggles correctly; seek bar advances.
- [ ] Dragging seek bar seeks correctly; playback continues from new position.
- [ ] Next advances to the next song in the library. Previous goes back.
- [ ] Mini-player shows current track while navigating to library screen.
- [ ] Audio continues when app is backgrounded (screen locked) on a **real device**.
- [ ] Lock screen and Control Centre show correct track metadata and Play/Pause controls.
- [ ] Incoming phone call pauses audio; audio resumes appropriately after call.
- [ ] Unplugging headphones pauses audio.
- [ ] After killing and relaunching the app, the last-played song and approximate position are restored.

> [!IMPORTANT]
> Phase 1C **requires a real iPhone** for the background playback acceptance tests. Simulator does not simulate background audio suspension.

---

### Phase 2 — Loop Button: Three-State Tap Cycle + Long-Press Guard
**Goal:** The Loop button short-tap cycle and long-press gesture are correct; the Custom Loop Editor stub opens.

**Work:**
- Implement `LoopMode` enum: `off`, `repeatOnce`, `repeatInfinite`, `finiteSection`, `infiniteSection`.
- Implement `LoopButton` widget:
  - `GestureDetector` with `onTap` and `onLongPressStart`.
  - `_longPressActive` flag: set in `onLongPressStart`, checked and cleared in `onTap`.
  - Short-tap cycles: `off → repeatOnce → repeatInfinite → off`.
  - Long-press opens `LoopEditorSheet` (stub returning `null` for now).
- Implement Repeat Once behavior in `AudioHandler`: on `processingState == completed`, if mode is `repeatOnce` → seek to 0 → play → set mode to `off` after completion.
- Implement Repeat Infinite behavior in `AudioHandler`: on `processingState == completed`, if mode is `repeatInfinite` → seek to 0 → play.
- Implement mode-specific icons: unhighlighted repeat icon (off), repeat icon + "1" badge (repeatOnce), ∞ symbol (repeatInfinite).

**Acceptance tests:**
- [ ] Short tap cycles Off → Repeat Once → Repeat Infinite → Off (visual icon changes correctly at each step).
- [ ] Repeat Once: song completes → replays once → advances to next track. Verified by waiting for song end.
- [ ] Repeat Once: does not replay twice; after one extra replay, mode returns to Off and queue advances.
- [ ] Repeat Infinite: song completes → replays → replays again (verify ≥ 3 consecutive repeats).
- [ ] Repeat Infinite: pressing Next exits the loop and advances the queue.
- [ ] Long-press on Loop button: editor stub sheet opens.
- [ ] Long-press does **not** change the loop mode state (no tap-cycle side-effect).

**Unit tests:**
- [ ] `LoopButton` widget test: fire a `longPress` gesture; assert `loopMode` state is unchanged after gesture.
- [ ] `LoopButton` widget test: fire three `tap` gestures; assert mode sequence is `off → repeatOnce → repeatInfinite → off`.

---

### Phase 3 — Section Loop Engine + Persistent Profiles + Next Priority
**Goal:** Finite and infinite section loops work correctly; profiles persist; Next from all sources always exits loops.

**Work:**
- Implement `ActiveLoopSession` with `trackGenerationId`, `seekPending`, `iterationsCompleted`, `isCompleted`.
- Implement `LoopController` inside `AudioHandler`:
  - Subscribes to `_player.positionStream`.
  - On each position event: if `seekPending || isCompleted || mode != finiteSection/infiniteSection` → ignore.
  - If `position >= loopEndMs - toleranceMs`: set `seekPending = true`; call `_player.seek(loopStart)`.
  - In seek completion (next position event ≤ loopStart + toleranceMs): clear `seekPending`.
  - For finite: after seek, increment `iterationsCompleted`; if `== finiteCount` → set `isCompleted = true` → seek to `loopEnd` → continue as Off.
  - `cancelSession()`: sets `isCompleted = true`, ignores all future events for current `trackGenerationId`.
- Implement `LoopEditorSheet` (text field UI for start/end/count; no waveform yet):
  - Pre-loads saved `LoopProfile` from DB.
  - Takes a snapshot of current state on open.
  - Cancel: restore snapshot (no DB write).
  - Save: validate range; write to DB; apply to active session.
- Override `AudioHandler.skipToNext()`: call `_loopController.cancelSession()` first, then advance queue and load next track's profile.
- Override `AudioHandler.skipToPrevious()`: same pattern.
- On track load: increment `trackGenerationId`; load profile from DB; initialize new session if profile mode is a section loop.
- Persist loop profiles to DB via `LoopProfileRepository`.

**Acceptance tests:**
- [ ] Finite section loop (N=3): region plays 3 times; after 3rd play, playback continues from `loopEnd`. Verify by watching seek bar.
- [ ] Finite section loop: does not play 4 times. Verify by counting.
- [ ] Infinite section loop: plays region > 20 times without stopping automatically.
- [ ] Pause mid-loop, resume: loop continues from correct position; iteration count is preserved.
- [ ] Seek within loop region: loop continues; no extra iteration increment.
- [ ] Seek outside loop region: loop deactivates; playback continues normally from seek position.
- [ ] In-app Next from infinite section loop → track advances. Loop does not block.
- [ ] Lock screen Next from infinite section loop → track advances. (Real device required.)
- [ ] Control Centre Next → track advances. (Real device required.)
- [ ] Loop profile saved: kill app, reopen, play same song → loop profile is restored.
- [ ] Switching to another track preserves the first track's saved profile. Return to first track → profile is there.
- [ ] Opening loop editor pre-fills saved values.
- [ ] Cancelling editor does not change saved profile.
- [ ] Saving editor with invalid range (start ≥ end) is rejected with an error message.

**Unit tests:**
- [ ] `LoopController` mock stream test: stream emits `[loopEnd - 10ms, loopEnd + 50ms]` after a seek; assert `seekCount == 1` (stale event ignored).
- [ ] `LoopController` mock test: finite loop N=2; stream: `[loopEnd, loopStart, loopEnd, loopStart, loopEnd]`; assert `seekCount == 2`, final state `isCompleted == true`.
- [ ] `LoopController` mock test: `cancelSession()` called; subsequent position events at `loopEnd` → no seek called.
- [ ] `LoopController` mock test: `trackGenerationId` incremented on track switch; old events from previous generation are ignored.

---

### Phase 4 — Waveform Editor
**Goal:** User can set loop boundaries by dragging handles on a waveform. Preview works.

**Work:**
- Integrate `just_waveform`: generate waveform data from audio file path; save `.wave` cache file alongside audio file.
- Build `WaveformEditor` widget:
  - Rendered waveform (custom `CustomPainter`).
  - Two draggable handles (start = green, end = red) with timestamp labels.
  - Selected region highlighted between handles.
  - Playhead synced to `audio_service` position stream (not raw `positionStream` in the UI).
- Fine-adjustment buttons: ±100ms step beside each handle.
- Boundary validation: handles cannot cross; cannot exceed `[0, duration]`.
- Preview button: seek to `max(0, loopStart - 2000ms)`, play; seek bar follows.
- Loading shimmer while waveform generates; error state if generation fails.
- Cache: if `songId.wave` file already exists, load from cache; skip generation.

**Acceptance tests:**
- [ ] Open waveform editor for a track → waveform renders within 5 seconds (or cache loads instantly).
- [ ] Dragging start handle moves it; end handle stays.
- [ ] Dragging end handle moves it; start handle stays.
- [ ] Attempting to drag start handle past end handle is blocked.
- [ ] Timestamp labels update correctly as handles move.
- [ ] ±100ms buttons move the handle by ~100ms.
- [ ] Preview plays approximately 2 seconds before the selected region.
- [ ] Waveform loads from cache immediately on second open of the same track.
- [ ] UI remains responsive while waveform generates in the background.

---

### Phase 5 — Auto Loop
**Goal:** Auto Loop suggests a region; user can preview and adjust it; it never overwrites without confirmation.

**Work:**
- Implement `AutoLoopAnalyzer` in a Dart isolate (actual CPU-intensive analysis work runs in `compute()`):
  - Load PCM samples using `just_audio` or an FFmpeg wrapper.
  - Compute short-time energy for silence detection.
  - Score boundary candidates using energy similarity.
  - Return top candidate `(startMs, endMs)` with confidence score.
- Present candidate in waveform editor with handles pre-set.
- Show loading / success / failure / retry states.
- If existing saved profile exists: prompt "Replace existing loop?" before applying.
- If no good candidate found: explain this honestly; allow manual selection.

> [!WARNING]
> **Honest limitation:** Dart-native audio analysis without FFmpeg is limited. Beat-aligned loop detection (FR-034, FR-035) requires access to PCM samples. The simplest viable approach is energy-based boundary detection. True beat/onset analysis in pure Dart is complex and may produce imprecise results. This will be flagged in implementation and the user will be able to adjust suggestions manually (FR-036).

**Acceptance tests:**
- [ ] Auto Loop button triggers analysis; loading state shows.
- [ ] Analysis completes; a suggested region appears in the waveform editor with handles.
- [ ] User can move handles and preview the suggestion.
- [ ] If existing profile exists: confirmation dialog appears before overwriting.
- [ ] If analysis fails: error message and retry button appear.
- [ ] Auto Loop does not write to the DB until the user presses Save.

---

### Phase 6 — Library Completeness, UI Polish, and Hardening
**Goal:** All library views work; UI is polished; all §15 acceptance criteria pass on a real device.

**Work:**
- Complete library tabs: Albums, Artists, Playlists, Recently Played, Favorites.
- Favorites: toggle from Now Playing or long-press in library.
- Basic playlist: create, rename, delete, add/remove songs.
- Recently played: track last-played timestamp; show in reverse order.
- Loop indicator overlay on Now Playing: remaining iterations for finite loops (e.g. "3 left"); ∞ badge for infinite section loops.
- Discoverable alternate Loop Editor entry: "Edit Loop" button in Now Playing options menu (for users who don't know the long-press gesture, per FR-043).
- Accessibility pass: semantic labels on all controls; minimum 44×44pt touch targets.
- Error states: empty library message; failed import; corrupted audio (catches `just_audio` exceptions).
- Full regression test of all Phase 1–5 acceptance criteria on real device.

**Acceptance tests (full §15 list):**
- All Phase 1–5 tests re-run on a real iPhone.
- [ ] Albums, Artists, Playlists, Recently Played, Favorites views populate correctly.
- [ ] Favorites toggle persists across restarts.
- [ ] Loop indicators show correct remaining count and ∞ badge.
- [ ] Alternative Loop Editor entry point opens the editor.
- [ ] VoiceOver can navigate all primary controls.

---

### Phase 7 — Regression and Performance
**Goal:** No regressions; performance is acceptable on a real iPhone.

**Work:**
- Full regression run of entire §15 acceptance criteria.
- Memory profile: waveform data for 5+ tracks loaded; heap stays within reason.
- Battery profile: 30-minute background loop session; no abnormal drain.
- Fix any regressions found.

---

## 8. Assumptions and Honest Limitations

### Confirmed facts

- `audio_service` v0.18.x does **not** use a separate Dart isolate on iOS. This is verified behavior.
- All Next command sources (lock screen, Control Centre, headphones) route to the same `skipToNext()` override. This is verified via the `MPRemoteCommandCenter` mechanism.
- `just_audio`'s `positionStream` continues firing in background when `audio_service` is active and background audio mode is set.
- `metadata_god` requires a Rust toolchain on the build machine. This is a real build-time requirement.

### Honest limitations and open questions

| # | Item | Status |
|---|---|---|
| 1 | **Headphone Next support** | Hardware-dependent. AirPods (gen 2+) support it; older Bluetooth headphones may not. Cannot guarantee without testing on specific hardware. |
| 2 | **Seek accuracy** | `just_audio` on iOS via AVFoundation seeks to the nearest keyframe for compressed audio (MP3, AAC). Sub-100ms accuracy for compressed files is not guaranteed (FR-028 acknowledges this). WAV/AIFF files can seek more accurately. |
| 3 | **Background loop engine reliability** | Verified that the main isolate stays alive during background audio. However, if the user force-quits the app, the process terminates. This is expected OS behavior and cannot be worked around. |
| 4 | **Auto Loop quality** | Dart-native audio analysis without FFmpeg is limited to energy-based heuristics. Beat-aligned or "musically perfect" loop detection (FR-034) is aspirational; results will vary by track. The editor allows manual correction. |
| 5 | **`just_waveform` version `0.0.7`** | Still in `0.0.x` — not a stable semver release. The API could change. Owned by the same author as `just_audio`; considered safe to use but should be monitored. |
| 6 | **Flutter SDK upgrade required** | Latest packages require Flutter 3.27.0. If your current Flutter installation is older, it must be updated before this project can be built. |
| 7 | **file_picker iOS 14.0 minimum** | `file_picker` v13.x sets iOS 14.0 as the minimum deployment target. Devices running iOS 12–13 would not be able to install this app. Given that iOS 14 launched in 2020, this is unlikely to affect a personal-use app. |
| 8 | **positionStream tolerance for loop boundary** | The exact tolerance window for detecting `position >= loopEndMs` (currently planned at ~200ms look-ahead) will require tuning on a real device. Too large a window wastes audio at the end of the region; too small risks missing the boundary if the stream poll interval is coarse. |

---

> [!CAUTION]
> **Awaiting your approval before any application code is written or modified.**
> The only file created so far is `PRD.md` in the project root (a pure document conversion, no code).
> Reply "Proceed with Phase 1A" (or any phase number) to begin, or request further changes to this plan.
