# Product Requirements Document (PRD)

**Personal Music Player with Intelligent Section Looping**

| Field | Value |
|---|---|
| Version | 1.2 |
| Platform | iOS |
| Framework | Flutter / Dart |
| Storage | Local-first, offline-capable |
| Development agent | Google Antigravity or another coding agent |

---

## 1. Executive Summary

Build a polished, Apple Music-inspired personal music player with a special focus on repeating specific portions of songs.

The app must support ordinary music playback, familiar repeat controls, custom finite and infinite section looping, waveform-based loop selection, and intelligent Auto Loop suggestions.

The interface should be simple for everyday listening while making advanced looping accessible through a long press. All essential playback and looping functionality must work reliably in the background and on the iOS lock screen.

---

## 2. Product Goals

1. Provide a clean, premium music-listening experience.
2. Support intuitive standard playback controls without requiring configuration.
3. Allow users to repeat a whole song or a selected section.
4. Support both finite and infinite section loops.
5. Persist each song's custom loop configuration.
6. Make precise section selection easy through waveform editing.
7. Provide optional automatic loop suggestions.
8. Keep the app usable offline with locally imported music.

---

## 3. Core User Experience

### 3.1 Standard Loop Button Behavior — Critical Requirement

The Loop button on the Now Playing screen must support ordinary repeat behavior through short taps and advanced customization through a long press.

**Short-tap cycle:**

| State | Button appearance | Behavior |
|---|---|---|
| Off | Unhighlighted repeat icon | Play normally; no repeat |
| Repeat once | Highlighted repeat icon with **1** | After the current play finishes, replay the whole song one additional time, then continue to the next track |
| Repeat infinitely | Highlighted repeat-one/infinity indicator | Repeat the whole song indefinitely until the user changes the mode or presses Next |
| Back to Off | Unhighlighted repeat icon | Return to normal playback |

A short tap cycles through these three states in order: **Off → Repeat once → Repeat infinitely → Off**.

The "Repeat once" mode means one additional replay, not one total play. If the song is already playing, finish the current play and then perform the additional play.

### 3.2 Long-Press Behavior — Critical Requirement

Long-pressing the Loop button must open the Custom Loop Editor.

- A long press must not accidentally trigger the short-tap cycle.
- The editor must offer Off, Finite Section Loop, and Infinite Section Loop.
- The user must be able to select the section manually or use Auto Loop.
- Existing saved loop settings must be loaded when appropriate.
- The editor must provide clear Save/Apply and Cancel actions.
- Cancelling must not overwrite the previous saved configuration.

### 3.3 Interaction Consistency

- Use familiar playback icons and standard tap behavior.
- Provide visual feedback for the current repeat mode.
- Show an obvious indication when a custom section loop is active.
- Use accessible touch targets and readable text.
- Ensure the long-press gesture works reliably on supported iPhones.
- Do not require the user to open a settings screen for everyday repeat behavior.

---

## 4. Music Library

**FR-001 — Import music:** Import supported local audio files through the iOS Files picker. Support MP3 and M4A/AAC, and WAV where supported by the playback stack.

**FR-002 — Persistent storage:** Copy imported audio into app-managed storage so files remain available after the original Files location changes.

**FR-003 — Library browsing:** Provide Songs, Albums, Artists, Playlists, Recently Played, and Favorites views.

**FR-004 — Search:** Search the local library by song title, artist, album, and other available metadata.

**FR-005 — Metadata:** Display title, artist, album artwork, and duration where available. Provide reasonable fallbacks for missing metadata.

**FR-006 — Library management:** Allow users to remove songs from the library, with clear confirmation where removal could delete the stored audio file.

---

## 5. Standard Playback

**FR-007 — Playback controls:** Provide Play/Pause, Previous, Next, seek bar, elapsed time, and total duration.

**FR-008 — Queue:** Provide a queue view, with predictable Next and Previous behavior.

**FR-009 — Background playback:** Continue audio during screen lock and while the app is backgrounded, subject to iOS system behavior.

**FR-010 — System media controls:** Integrate with Now Playing, the lock screen, Control Centre, and supported headphone media controls.

**FR-011 — Playback persistence:** Preserve the current song and sensible playback position across interruptions and app restarts.

**FR-012 — Audio interruptions:** Handle calls, other audio sessions, headphone disconnection, and audio-session interruptions gracefully.

**FR-013 — Seeking:** Manual seeking must not leave playback stuck, cause duplicate loop transitions, or trigger stale loop callbacks.

---

## 6. Custom Section Looping

**FR-014 — Select a region:** Let the user choose a start and end position within a song.

**FR-015 — Finite section loop:** Repeat the selected region for a user-configured number of total plays in the looping sequence, then continue playback from the end of the selected region by default.

**FR-016 — Infinite section loop:** Repeat the selected region indefinitely, without an automatic repeat limit or automatic exit.

**FR-017 — Explicit exit behavior:** An infinite section loop must exit when the user explicitly presses Next through the in-app button, lock-screen/Now Playing controls, Control Centre, or supported headphone media controls. The user must also be able to disable the custom loop explicitly.

**FR-018 — Track-specific configuration:** Save loop start, loop end, loop mode, repeat count, and other relevant settings per song.

**FR-019 — Persistent profiles:** Switching to another song must not erase the previous song's saved configuration. Replaying a song should restore its saved loop configuration.

**FR-020 — Separate saved and transient state:** Keep the saved loop profile separate from the current playback position, repeat counter, and active looping session.

**FR-021 — Finite loop completion:** After the configured number of plays, exit the section loop exactly once and continue from the loop end. Do not accidentally re-enter the loop because of a stale playback-position event.

**FR-022 — Next-track priority:** A Next command must cancel pending loop transitions, terminate the current looping session, advance the queue, and load the next track's own saved profile. An infinite loop must never block Next.

**FR-023 — Pause and resume:** Pause and resume must preserve the selected section, repeat count progress, and current mode.

**FR-024 — Loop validation:** Reject or correct invalid ranges, including a start position at or after the end position and regions outside the song duration.

**FR-025 — Loop indicators:** Display whether the current mode is whole-song repeat or custom section repeat. For finite loops, show remaining repetitions when useful; for infinite loops, display an infinity indicator.

---

## 7. Waveform Editor

**FR-026 — Waveform display:** Render a waveform for the current track or selected region.

**FR-027 — Draggable handles:** Provide distinct start and end handles with timestamps.

**FR-028 — Precision adjustment:** Support fine adjustments targeting approximately 100 ms where the audio engine and seeking accuracy permit. Do not promise sample-accurate editing unless verified.

**FR-029 — Preview:** Allow users to preview the selected region before saving.

**FR-030 — Boundary adjustments:** Allow users to move either boundary without unintentionally moving the other.

**FR-031 — Waveform caching:** Cache generated waveform data where practical to reduce repeated processing.

**FR-032 — Editing feedback:** Clearly indicate the selected region and prevent handles from crossing into an invalid range.

---

## 8. Auto Loop

**FR-033 — Target duration:** Let the user specify a desired loop duration, with a sensible default and configurable range.

**FR-034 — Selection preferences:** Offer musically aligned, energy-based, and exact-duration selection preferences where practical.

**FR-035 — Candidate analysis:** Use audio features such as short-time energy, onset strength, beat estimates, boundary similarity, and phrase coherence to identify potential loop points.

**FR-036 — Candidate preview:** Present a suggested region with adjustable handles and a preview action.

**FR-037 — Apply confirmation:** Never overwrite an existing saved loop profile without user confirmation.

**FR-038 — Honest feedback:** If no good candidate is found, explain that result and allow manual selection. Do not claim perfect musical transitions.

**FR-039 — Processing states:** Show loading, success, and failure states with a retry option.

---

## 9. Now Playing UI

**FR-040 — Main layout:** Include artwork, track information, seek bar, playback controls, and the Loop button.

**FR-041 — Loop button placement:** Make the Loop button easy to reach without crowding primary playback controls.

**FR-042 — Active state:** Distinguish Off, Repeat once, Repeat infinitely, Finite section loop, and Infinite section loop visually.

**FR-043 — Custom editor entry:** Long-press the Loop button to open the Custom Loop Editor. Also provide a discoverable alternative entry point for users who do not know the gesture.

**FR-044 — Mini-player:** Show the current track and playback status while navigating the library.

**FR-045 — Navigation:** Provide library, search, Now Playing, and queue navigation without unnecessarily interrupting playback.

---

## 10. Standard Music-Player Features

The following are expected baseline usability features, not optional premium features:

- Play/Pause, Next, Previous, and seeking.
- Queue management and predictable track transitions.
- Song search and recently played history.
- Favorites and basic playlist management.
- Album artwork and metadata fallbacks.
- Clear playback and repeat-mode indicators.
- Audio interruption handling.
- Accessible controls, useful error messages, and confirmation for destructive actions.
- Sensible empty-library, unsupported-file, and failed-import states.
- Persistent playback and per-song loop settings.

Additional features such as lyrics, equalizer, playback-speed control, crossfade, listening statistics, and vocal separation may be considered after the core player is stable.

---

## 11. Technical Architecture

Use Flutter and Dart with an iOS-focused implementation.

Candidate packages, subject to compatibility checks:

- **just_audio** — audio playback and seeking.
- **audio_service** — background playback and system media controls.
- **audio_session** — iOS audio-session management.
- **file_picker** — importing files.
- **sqflite** — persistent local database.
- **path_provider** and **path** — app storage management.

The playback engine must have a single authoritative state model for the current track, queue, repeat mode, active section loop, and pending loop transitions.

The custom loop engine must cooperate with the playback engine rather than competing with it through independent timers or uncontrolled position listeners.

---

## 12. Database Requirements

Use a local database for persistent metadata and loop profiles.

**Suggested song fields:**

- Song ID, title, artist, album, duration, artwork reference, stored file path.
- Import date and last-played timestamp.

**Suggested per-song loop-profile fields:**

- Song ID.
- Loop configuration type.
- Start and end positions.
- Repeat mode: Off, Repeat once, Repeat infinitely, Finite section loop, or Infinite section loop.
- Finite repeat count.
- Optional Auto Loop preferences.
- Last-modified timestamp.

Transient runtime state — such as the active finite-loop counter — must not overwrite the saved profile unintentionally.

---

## 13. Playback State and Transition Rules

The implementation must explicitly define transitions for:

- Normal playback.
- Whole-song Repeat once.
- Whole-song Repeat infinitely.
- Finite section looping.
- Infinite section looping.
- Paused playback.
- Manual seeking.
- Track switching.
- End-of-track handling.
- Audio interruption and recovery.

**Priority rules:**

1. An explicit Next command takes priority over every repeat or section-loop transition.
2. A saved profile does not by itself imply that the player must be actively looping when another track is playing.
3. Only one active loop configuration may control playback at a time.
4. Whole-song repeat and custom section looping must not fight over playback position.
5. Finite counters must advance only when a complete loop iteration is confirmed.
6. Infinite section loops must have no automatic exit based on a repeat count.
7. Switching tracks must cancel stale callbacks from the previous track.
8. Manual seeking and mode changes must leave the playback engine in a valid state.

---

## 14. Non-Functional Requirements

- Reliable offline playback for imported files.
- Responsive interface and waveform editing.
- Reasonable battery and memory usage.
- Persistence across app restarts.
- Accessible labels and touch targets.
- No backend required for core playback.
- Clear handling of file access and storage failures.
- Secure handling of local files and app permissions.
- Maintainable, modular code with meaningful tests.

---

## 15. Testing and Acceptance Criteria

### Standard Loop Button

- Verify the Off → Repeat once → Repeat infinitely → Off tap cycle.
- Verify Repeat once performs exactly one additional full-song play.
- Verify Repeat infinitely continues repeating until the mode changes or Next is pressed.
- Verify long-press opens the custom editor without also triggering a short tap.
- Verify visual indicators accurately represent each mode.

### Custom Section Loops

- Verify valid start/end selection and fine adjustments.
- Verify finite loops complete the configured number of plays and continue from the loop end.
- Verify infinite loops continue beyond 20 repetitions without stopping automatically.
- Verify pause/resume preserves loop state.
- Verify saved loop profiles survive app restarts and track switching.
- Verify cancelling the editor does not overwrite saved settings.
- Verify Auto Loop candidates can be previewed and adjusted.

### System Controls and Edge Cases

- Verify Next from the app exits an infinite loop.
- Verify Next from the lock screen and Control Centre exits an infinite loop.
- Verify supported headphone Next controls exit an infinite loop.
- Verify the next track loads its own saved loop profile.
- Verify Previous, seeking, end-of-track handling, and queue changes.
- Verify audio interruptions and background playback on a real iPhone.
- Verify corrupted or unsupported audio files fail gracefully.

---

## 16. Development Milestones

- **Phase 1:** Flutter project setup, iOS build, local music import, library, and standard playback.
- **Phase 2:** Standard Loop button, three-state tap cycle, and long-press gesture.
- **Phase 3:** Custom finite/infinite section-loop engine, persistent profiles, and Next-control priority.
- **Phase 4:** Waveform editor, preview, and boundary adjustment.
- **Phase 5:** Auto Loop analysis and candidate selection.
- **Phase 6:** Background playback, lock-screen/Control Centre integration, headphone controls, and UI polish.
- **Phase 7:** Comprehensive regression testing and performance improvements.

Do not begin advanced features until ordinary playback and looping are reliable.

---

## 17. Instructions for the Coding Agent

Read the complete PRD before writing code. Treat it as the authoritative specification regardless of whether the coding agent is Claude Code, Antigravity, or another tool.

**Before implementation:**

1. Inspect the project structure and existing code.
2. Identify the required packages and verify their current APIs and iOS compatibility.
3. Propose a phased implementation plan.
4. Identify technical risks, especially background playback and system Next commands.
5. Define how loop-state transitions will be tested.
6. Ask for approval before making major architectural changes.

**During implementation:**

- Do not omit requirements simply because they are not explicitly repeated in a prompt.
- Implement standard usability behavior proactively.
- Keep code modular and maintainable.
- Do not silently replace infinite looping with a finite limit.
- Do not let Next controls become blocked by looping.
- Do not claim a feature works until it has been tested.
- Report limitations and unresolved issues honestly.

---

## 18. Definition of Done

The app is ready for its initial release to personal use when:

- Users can import and play local songs.
- Standard playback controls behave predictably.
- The Loop button supports the specified short-tap cycle and long-press editor.
- Whole-song and section-loop modes work correctly.
- Finite and infinite section-loop settings persist per song.
- Infinite loops can always be exited through supported Next controls.
- Waveform editing and Auto Loop work reliably enough for real use.
- Background playback and system media controls have been tested on a real iPhone.
- The core app remains usable offline.

**Final product principle:** Make ordinary listening effortless, advanced looping powerful, and playback behavior dependable. Standard usability features should be included proactively, not left for the user to discover and request one by one.
