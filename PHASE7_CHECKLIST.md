# Phase 7 checklist: regression + performance on the real iPhone

How to use: run the app on your iPhone (`flutter run -d <iPhone ID>`), go
through the lines, and tick them. If a line FAILS, write what you saw next to
it and paste that line to Claude. Skipped on purpose: Auto Loop (Phase 5),
VoiceOver / accessibility, lock-screen loop state, Albums and Artists.

Tip: use at least 5 songs, and one short (under 1 min) plus one long (over
5 min) if you have them.

## A. Loop button (the tap cycle)
- [✅] Tap cycle: Off -> Repeat once -> Repeat infinitely -> Off.
- [✅] Repeat once plays the whole song exactly one extra time, then continues.
- [✅] Repeat infinitely keeps going until you change the mode or press Next.
- [✅] Long press opens the loop editor and does NOT also change the mode.
- [✅] The button looks different in each mode.

## B. Section loops (the editor)
- [✅ ] Set Start and End (handles and the +/- 100 ms buttons), then Save.
- [✅ ] Preview plays the chosen region.
- [✅ ] A finite loop (e.g. 3 plays) plays exactly that many times, then the song
      continues past the loop end.
- [✅ ] An infinite loop is still going after 20+ repeats.
- [✅ ] While the loop is set but not reached yet, the card says Waiting; inside
      it says Running with the plays left (or the infinity sign).
- [✅ ] The "Edit loop" button opens the editor (same as the long press).
- [✅ ] Cancel in the editor does NOT change the saved loop.
- [✅ ] Pause then Play keeps the loop state.
- [✅ ] Seek (drag the bar) before / inside / after the loop: no stuck playback,
      no double loop jumps.
- [✅ ] Close the app completely and reopen: the loop of each song is still saved.
- [✅ ] Switch to another song and back: its own loop is still there.

## C. Leaving loops, system controls, interruptions
- [✅ ] Next in the app exits an infinite loop.
- [✅ ] Next on the lock screen exits an infinite loop.
- [✅ ] Next in Control Centre exits an infinite loop.
- [✅ ] Headphone Next (if your headphones have it) exits an infinite loop.
- [✅ ] The next song loads its OWN saved loop (or none).
- [✅ ] Previous: restarts the song after a few seconds, goes back when near the
      start.
- [✅ ] Song ends normally: moves to the next song in the queue.
- [✅ ] Lock the screen: music keeps playing; lock-screen play/pause/next work.
- [✅ ] Phone call or another app's audio interrupts, then playback behaves
      sensibly afterwards.
- [✅ ] Unplug wired headphones / disconnect Bluetooth: music pauses.

## D. Library
- [✅ ] Import several MP3 / M4A files; they appear with title, artist, artwork,
      duration (missing tags show "Unknown Artist" and a placeholder picture).
- [✅ ] Search finds songs by title and by artist.
- [✅ ] Remove a song (long press or menu): asks first; the song disappears;
      if it was playing, playback stops cleanly.
- [✅ ] Heart a song: it appears in Favorites; un-heart: it leaves. Survives a
      restart.
- [✅ ] Play 3 songs: Recently Played shows them newest first.
- [✅ ] Playlists: create, rename, delete, add / remove songs, duplicate name
      refused, a song removed from the library leaves its playlists.
- [✅ ] Queue: opens from Now Playing, tap to jump, X removes, current song has
      no X.
- [✅ ] Mini player shows the current song while browsing; tapping opens Now
      Playing.
- [✅ ] Empty library shows the friendly empty message.

## E. Errors
- [✅ ] A damaged or unsupported file fails with a message and does not crash
      or freeze playback.

## F. Persistence
- [✅ ] Force-quit mid-song and reopen: the song and roughly the position are
      restored (paused).
- [✅ ] Hearts, playlists, loops, and the library are all still there.

## G. Performance (note the numbers, do not worry about perfection)
- [✅] Scrolling the library and switching tabs feels smooth (note the number
      of songs you have).
- [✅] Opening the loop editor for 5+ different songs one after another: still
      smooth, no crash.
- [✅] Memory: run `flutter run --profile -d <iPhone ID>`, open the DevTools link
      it prints, and look at the Memory tab. Write down the memory after
      opening the editor for 5 songs: ______ MB.
- [✅] Battery: play an infinite section loop with the screen locked for 30
      minutes. Afterwards note the battery drop: ______ % (and, in the iPhone's
      Settings under Battery, whether LoopPlayer looks unusually high).
- [✅] After the 30 minutes the loop is still playing and the app responds.
