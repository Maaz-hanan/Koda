import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' hide LoopMode;

import '../../core/storage_paths.dart';
import '../../data/database/app_database.dart';
import '../../data/database/loop_profile_dao.dart';
import '../../data/database/song_dao.dart';
import '../../data/models/loop_profile.dart';
import '../../data/models/song.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/loop_profile_repository.dart';
import '../../data/services/playback_persistence.dart';
import '../loop/loop_mode.dart';
import '../loop/loop_status.dart';
import '../loop/section_loop_engine.dart';
import '../loop/whole_song_repeat.dart';
import 'playback_restore.dart';
import 'preview_session.dart';
import 'queue_manager.dart';

/// The ONE owner of the audio player. [PRD §11]
///
/// The screens never touch AudioPlayer. They call methods on this class,
/// and the lock screen / Control Centre / headphones call the same methods
/// (play, pause, skipToNext, ...) through audio_service. So the "Next"
/// rules we write here apply to every source automatically.
///
/// Whole-song repeat (Phase 2) and custom section looping (Phase 3)
/// plug into position updates, track completion, and track-changing commands.
class LoopPlayerAudioHandler extends BaseAudioHandler with SeekHandler {
  LoopPlayerAudioHandler({
    PlaybackPersistence? persistence,
    LoopProfileRepository? loopProfiles,
    LibraryRepository? library,
  })  : _persistence = persistence ?? PlaybackPersistence(),
        _loopProfiles = loopProfiles ??
            LoopProfileRepository(LoopProfileDao(AppDatabase.instance)),
        _library = library ?? LibraryRepository(SongDao(AppDatabase.instance)) {
    _ready = _init();
  }

  final PlaybackPersistence _persistence;
  final LoopProfileRepository _loopProfiles;
  final LibraryRepository _library;
  final AudioPlayer _player = AudioPlayer();
  final QueueManager _queueManager = QueueManager();

  /// Decides what happens at the end of a song (Off / Once / Infinite).
  final WholeSongRepeat _repeat = WholeSongRepeat();

  /// Manages custom finite/infinite section loops. [PRD FR-014..FR-025]
  final SectionLoopEngine _sectionLoop = SectionLoopEngine();

  /// Active loop mode (whole song or section loop).
  LoopMode _currentMode = LoopMode.off;

  /// Non-null while the loop editor's Preview is playing. [PRD FR-029]
  PreviewSession? _preview;
  final StreamController<bool> _previewChanges =
      StreamController<bool>.broadcast();

  bool get isPreviewing => _preview != null;
  Stream<bool> get previewingStream => _previewChanges.stream;

  /// The generation (= the song load) whose "played" time is already saved,
  /// so one load is recorded once, not on every pause / resume.
  int _playRecordedGeneration = -1;
  final StreamController<String> _songPlayed =
      StreamController<String>.broadcast();

  /// Emits a song's id after its "last played" time was saved, so the
  /// library can reload. [PRD FR-005]
  Stream<String> get songPlayedStream => _songPlayed.stream;

  /// Saves "this song started playing now". Failure is ignored: a missing
  /// "recently played" entry must never stop the music.
  void _recordPlayed(Song song, int generation) {
    if (_playRecordedGeneration == generation) return;
    _playRecordedGeneration = generation;
    unawaited(_markPlayed(song.id));
  }

  Future<void> _markPlayed(String songId) async {
    try {
      await _library.markPlayed(songId, DateTime.now().millisecondsSinceEpoch);
      _songPlayed.add(songId);
    } catch (_) {}
  }

  /// What the Now Playing screen shows about the section loop (range,
  /// waiting / running, plays left). Null when there is no loop. [PRD FR-025]
  SectionLoopStatus? _loopStatus;
  final StreamController<SectionLoopStatus?> _loopStatusChanges =
      StreamController<SectionLoopStatus?>.broadcast();

  SectionLoopStatus? get loopStatus => _loopStatus;
  Stream<SectionLoopStatus?> get loopStatusStream => _loopStatusChanges.stream;

  /// Takes a fresh snapshot of the engine and tells the screen, but only if
  /// something changed (position events arrive every ~200 ms).
  void _publishLoopStatus() {
    final next = SectionLoopStatus.fromSession(_sectionLoop.session);
    if (next == _loopStatus) return;
    _loopStatus = next;
    _loopStatusChanges.add(next);
  }

  final StreamController<LoopMode> _repeatChanges =
      StreamController<LoopMode>.broadcast();
  final StreamController<String> _errors = StreamController<String>.broadcast();

  late final Future<void> _ready;

  /// Bumped every time we load a track or stop. A load that finishes after a
  /// newer one has started notices the number changed and gives up, so stale
  /// work from a previous track can never affect the current one.
  int _generation = 0;

  /// The [_generation] of the most recent load that finished successfully.
  /// We only save the position when this equals [_generation]; otherwise the
  /// player may still be showing the PREVIOUS song's position.
  int _loadedGeneration = -1;

  /// The current repeat / loop mode, and a stream of changes to it.
  LoopMode get repeatMode => _currentMode;
  Stream<LoopMode> get repeatModeStream => _repeatChanges.stream;

  void _setMode(LoopMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      _repeatChanges.add(_currentMode);
    }
  }

  /// Short tap on the Loop button:
  /// If in a section loop -> switches to Off (cancels active session; keeps saved profile).
  /// Otherwise cycles Off -> Once -> Infinite -> Off. [PRD §3.1, PLAN §4.2]
  void cycleRepeatMode() {
    final next = nextRepeatMode(_currentMode);
    _sectionLoop.cancelSession();
    _repeat.setMode(next);
    _setMode(next);
    _publishLoopStatus();
  }

  /// A different song is about to play, so whole-song repeat and section loop end.
  /// Call this BEFORE any await, so nothing stale can fire in between.
  void _endRepeat() {
    _finishPreview(syncLoop: false);
    _repeat.onTrackChange();
    _sectionLoop.cancelSession();
    _setMode(LoopMode.off);
    _publishLoopStatus();
  }

  /// Human-readable playback problems (e.g. a damaged file) for the UI.
  Stream<String> get errors => _errors.stream;

  Future<void> _init() async {
    // Tell iOS this app plays music. just_audio uses this session to pause
    // for calls and when headphones are unplugged.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.playbackEventStream.map(_transformEvent).listen(
      playbackState.add,
      onError: (Object error, StackTrace stack) {
        // Load failures are reported where the load happens; ignore here.
      },
    );

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        unawaited(_onTrackCompleted());
      }
    });

    // Section loop engine monitors position to seek back at loopEnd.
    _player.positionStream.listen(_onPositionChanged);

    // Remember where we are whenever playback pauses...
    _player.playingStream.listen((playing) {
      if (!playing) unawaited(saveNow());
    });

    // ...and every 5 seconds while playing, so a kill or crash loses little.
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (_player.playing) unawaited(saveNow());
    });
  }

  void _onPositionChanged(Duration position) {
    if (_queueManager.current == null || _loadedGeneration != _generation) {
      return;
    }

    // During Preview only the preview watches the position; the saved loop
    // is paused so the two cannot fight. [PRD §13 rule 3]
    final preview = _preview;
    if (preview != null) {
      if (preview.onPosition(position.inMilliseconds, _generation) ==
          PreviewAction.finished) {
        _finishPreview(pause: true);
      }
      return;
    }

    final action =
        _sectionLoop.onPosition(position.inMilliseconds, _generation);
    switch (action) {
      case SectionLoopAction.seekToStart:
        final session = _sectionLoop.session;
        if (session != null) {
          unawaited(_player.seek(Duration(milliseconds: session.loopStartMs)));
        }
        break;
      case SectionLoopAction.loopCompleted:
        final session = _sectionLoop.session;
        _setMode(LoopMode.off);
        if (session != null) {
          unawaited(_player.seek(Duration(milliseconds: session.loopEndMs)));
        }
        break;
      case SectionLoopAction.none:
        break;
    }
    _publishLoopStatus();
  }

  // -------------------------------------------------------------------------
  // Our own commands (called by screens)
  // -------------------------------------------------------------------------

  /// Starts playing [songs] from [startIndex].
  Future<void> playQueue(List<Song> songs, int startIndex) async {
    if (songs.isEmpty) return;
    _endRepeat();
    _queueManager.setQueue(songs, startIndex);
    // Shuffle stays on when a new list is started: mix what comes next.
    if (_shuffleOn) _queueManager.shuffleUpcoming(_random);
    queue.add(_queueManager.songs.map(_toMediaItem).toList());
    await _loadCurrentAndPlay();
  }

  // ---- Volume (the app's own volume, 0..1, relative to the phone's) ----

  double _volume = 1.0;
  final StreamController<double> _volumeChanges =
      StreamController<double>.broadcast();

  double get volume => _volume;
  Stream<double> get volumeStream => _volumeChanges.stream;

  /// Sets the app volume. While the slider is dragged call with
  /// `save: false`; on release call with the default so it is remembered.
  Future<void> setVolume(double v, {bool save = true}) async {
    final clamped = v.clamp(0.0, 1.0).toDouble();
    _volume = clamped;
    _volumeChanges.add(clamped);
    try {
      await _player.setVolume(clamped);
    } catch (_) {
      // A failed volume change must never break playback.
    }
    if (save) await _persistence.saveVolume(clamped);
  }

  // ---- Shuffle [PRD FR-008] ----

  final math.Random _random = math.Random();
  bool _shuffleOn = false;
  final StreamController<bool> _shuffleChanges =
      StreamController<bool>.broadcast();

  bool get shuffleEnabled => _shuffleOn;
  Stream<bool> get shuffleStream => _shuffleChanges.stream;

  void _setShuffleFlag(bool on) {
    if (_shuffleOn == on) return;
    _shuffleOn = on;
    _shuffleChanges.add(on);
  }

  /// Shuffle on: mixes the songs after the current one. Off: puts the queue
  /// back in its original order. The song that is playing is never touched.
  Future<void> setShuffle(bool on) async {
    _setShuffleFlag(on);
    if (_queueManager.songs.isEmpty) return;
    if (on) {
      _queueManager.shuffleUpcoming(_random);
    } else {
      _queueManager.restoreOrder();
    }
    queue.add(_queueManager.songs.map(_toMediaItem).toList());
    await saveNow(); // the saved queue order changed
  }

  Future<void> toggleShuffle() => setShuffle(!_shuffleOn);

  /// The "Shuffle" buttons: plays all of [songs] in random order and turns
  /// shuffle on.
  Future<void> playShuffled(List<Song> songs) async {
    if (songs.isEmpty) return;
    _setShuffleFlag(true);
    _endRepeat();
    _queueManager.setShuffledQueue(songs, _random);
    queue.add(_queueManager.songs.map(_toMediaItem).toList());
    await _loadCurrentAndPlay();
  }

  /// "Play next": [song] plays right after the current song. [PRD FR-008]
  Future<QueueAddResult> playSongNext(Song song) =>
      _changeQueue(song, _queueManager.playNext);

  /// "Add to queue": [song] goes to the end of the queue. [PRD FR-008]
  Future<QueueAddResult> addSongToQueue(Song song) =>
      _changeQueue(song, _queueManager.addToEnd);

  Future<QueueAddResult> _changeQueue(
    Song song,
    QueueAddResult Function(Song) change,
  ) async {
    // Nothing queued yet: there is nothing to add to, so just play it.
    if (_queueManager.songs.isEmpty) {
      await playQueue([song], 0);
      return QueueAddResult.started;
    }
    final result = change(song);
    if (result == QueueAddResult.added || result == QueueAddResult.moved) {
      queue.add(_queueManager.songs.map(_toMediaItem).toList());
      await saveNow(); // the saved queue changed
    }
    return result;
  }

  /// Applies a newly saved or updated loop profile immediately if it belongs
  /// to the currently playing song. [PLAN §4.2]
  Future<void> applyLoopProfile(LoopProfile profile) async {
    final song = _queueManager.current;
    if (song == null || song.id != profile.songId) return;

    // A new loop was saved: any preview is over, the new loop takes charge.
    _finishPreview(syncLoop: false);

    // Clear any active whole-song repeat
    _repeat.setMode(LoopMode.off);

    final durationMs = _player.duration?.inMilliseconds ?? song.durationMs;
    if (profile.isSectionMode &&
        profile.validate(durationMs: durationMs) == null) {
      _sectionLoop.startSession(
        loopStartMs: profile.loopStartMs!,
        loopEndMs: profile.loopEndMs!,
        isFinite: profile.mode == LoopMode.finiteSection,
        finiteCount: profile.finiteCount ?? 1,
        trackGeneration: _generation,
      );
      // The loop is only ARMED: playback is NOT moved. The loop takes over
      // when the song reaches the loop start by itself.
      _setMode(profile.mode);
    } else {
      _sectionLoop.cancelSession();
      _setMode(LoopMode.off);
    }
    _publishLoopStatus();
  }

  /// Previews [startMs]..[endMs] of the CURRENT song: plays from exactly
  /// [startMs] and pauses at [endMs]. Works on the unsaved values from the
  /// editor and never changes the saved loop. Returns false if [songId] is not
  /// the song that is loaded. [PRD FR-029]
  Future<bool> previewRegion({
    required String songId,
    required int startMs,
    required int endMs,
  }) async {
    final song = _queueManager.current;
    if (song == null || song.id != songId || _loadedGeneration != _generation) {
      return false;
    }
    if (startMs < 0 || endMs <= startMs) return false;

    final generation = _generation;
    final session = PreviewSession(
      regionStartMs: startMs,
      endMs: endMs,
      trackGeneration: generation,
    );
    _preview = session;
    _previewChanges.add(true);
    try {
      await _player.seek(Duration(milliseconds: session.playFromMs));
    } catch (_) {
      if (_preview == session) _finishPreview(syncLoop: false);
      return false;
    }
    // Next / seek / another preview may have taken over while seeking.
    if (generation != _generation || _preview != session) return true;
    unawaited(_player.play());
    return true;
  }

  /// Ends Preview. [pause] true (the Stop button) also pauses playback;
  /// false (editor closed) lets the song carry on normally.
  void stopPreview({bool pause = true}) => _finishPreview(pause: pause);

  /// Leaves preview mode. With [syncLoop] the saved loop is told where
  /// playback is now, exactly as after a manual seek (re-armed if before
  /// Start, ended if past End), so it stays in a valid state. [PRD FR-013]
  void _finishPreview({bool pause = false, bool syncLoop = true}) {
    if (_preview == null) return;
    _preview = null;
    _previewChanges.add(false);
    if (pause) unawaited(_player.pause());
    if (syncLoop) {
      _sectionLoop.onManualSeek(_player.position.inMilliseconds);
      if (!_sectionLoop.hasActiveSession &&
          (_currentMode == LoopMode.finiteSection ||
              _currentMode == LoopMode.infiniteSection)) {
        _setMode(LoopMode.off);
      }
      _publishLoopStatus();
    }
  }

  /// Saves the queue, current song and position. [PRD FR-011]
  /// Safe to call at any time; does nothing if there is nothing to save.
  Future<void> saveNow() async {
    final song = _queueManager.current;
    if (song == null) return;
    if (_loadedGeneration != _generation) return; // still loading a song
    final state = _player.processingState;
    if (state != ProcessingState.ready && state != ProcessingState.buffering) {
      return;
    }
    await _persistence.save(SavedPlayback(
      queueIds: _queueManager.songs.map((s) => s.id).toList(),
      currentId: song.id,
      positionMs: _player.position.inMilliseconds,
    ));
  }

  /// Called once at launch. Loads the last song PAUSED at its saved position.
  /// Never starts playing by itself. Any problem is ignored: the app simply
  /// starts with nothing loaded. [PRD FR-011]
  Future<void> restoreLastSession(List<Song> library) async {
    try {
      // The volume is restored first, so it applies even with no saved song.
      final savedVolume = await _persistence.loadVolume();
      if (savedVolume != null) await setVolume(savedVolume, save: false);

      final saved = await _persistence.load();
      if (saved == null) return;

      final restored = resolveRestore(saved, library);
      if (restored == null) {
        // The saved song no longer exists.
        await _persistence.clear();
        return;
      }

      _queueManager.setQueue(restored.songs, restored.startIndex);
      queue.add(restored.songs.map(_toMediaItem).toList());
      await _loadCurrentAndPlay(
        autoPlay: false,
        initialPosition: Duration(milliseconds: restored.positionMs),
      );
    } catch (_) {
      // Restoring is a nicety; never let it break app start-up.
    }
  }

  /// Call BEFORE deleting a song from the library. If it is playing, playback
  /// stops (we must not delete a file that is being played).
  Future<void> removeFromQueue(String songId) async {
    final wasCurrent = _queueManager.remove(songId);
    if (wasCurrent) _endRepeat();
    queue.add(_queueManager.songs.map(_toMediaItem).toList());
    if (wasCurrent) {
      _generation++;
      await _player.stop();
      mediaItem.add(null);
      await _persistence.clear();
    } else {
      await saveNow(); // the saved queue changed
    }
  }

  // -------------------------------------------------------------------------
  // Standard audio_service commands (screens AND lock screen use these)
  // -------------------------------------------------------------------------

  @override
  Future<void> play() async {
    final song = _queueManager.current;
    if (song == null) return;
    // play() finishes only when playback ends or pauses, so don't await it.
    unawaited(_player.play());
    if (_loadedGeneration == _generation) _recordPlayed(song, _generation);
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) async {
    _finishPreview(syncLoop: false); // the normal seek rules below take over
    _sectionLoop.onManualSeek(position.inMilliseconds);
    if (!_sectionLoop.hasActiveSession &&
        (_currentMode == LoopMode.finiteSection ||
            _currentMode == LoopMode.infiniteSection)) {
      _setMode(LoopMode.off);
    }
    _publishLoopStatus();
    return _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_queueManager.current == null) return;
    // Next always wins over every repeat or section-loop transition.
    // [PRD FR-017, FR-022, §13 rule 1]
    _endRepeat();
    if (_queueManager.moveToNext()) {
      await _loadCurrentAndPlay();
    } else {
      await _finishQueue();
    }
  }

  /// Jumps to a song in the queue (tap in the queue view). Like Next, it
  /// wins over every repeat or section-loop transition. [PRD FR-008, FR-022]
  @override
  Future<void> skipToQueueItem(int index) async {
    if (_queueManager.current == null) return;
    if (index < 0 || index >= _queueManager.songs.length) return;
    _endRepeat();
    if (_queueManager.moveTo(index)) await _loadCurrentAndPlay();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queueManager.current == null) return;
    // Like most players: if we're a few seconds in, restart the song first.
    if (_player.position > const Duration(seconds: 3) ||
        !_queueManager.hasPrevious) {
      _finishPreview(syncLoop: false);
      _sectionLoop.onManualSeek(0);
      if (!_sectionLoop.hasActiveSession &&
          (_currentMode == LoopMode.finiteSection ||
              _currentMode == LoopMode.infiniteSection)) {
        _setMode(LoopMode.off);
      }
      _publishLoopStatus();
      await _player.seek(Duration.zero);
      return;
    }
    _endRepeat();
    _queueManager.moveToPrevious();
    await _loadCurrentAndPlay();
  }

  @override
  Future<void> stop() async {
    await _resetToIdle();
    await super.stop();
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  Future<void> _loadCurrentAndPlay({
    bool autoPlay = true,
    Duration initialPosition = Duration.zero,
  }) async {
    await _ready;
    final song = _queueManager.current;
    if (song == null) return;

    final generation = ++_generation;
    _endRepeat();
    mediaItem.add(_toMediaItem(song));

    try {
      final duration = await _player.setFilePath(
        song.absoluteFilePath,
        initialPosition: initialPosition,
      );
      if (generation != _generation) return; // a newer request took over
      if (duration != null) {
        mediaItem.add(_toMediaItem(song, duration: duration));
        // A saved position at (or past) the very end would be useless.
        if (initialPosition >= duration - const Duration(seconds: 1)) {
          await _player.seek(Duration.zero);
          if (generation != _generation) return;
        }
      }
      _loadedGeneration = generation;

      // Restore saved loop profile for this song [PRD FR-018, FR-019]
      final profile = await _loopProfiles.getProfile(song.id);
      if (generation != _generation) return;

      final effectiveDurationMs = duration?.inMilliseconds ?? song.durationMs;
      if (profile.isSectionMode &&
          profile.validate(durationMs: effectiveDurationMs) == null) {
        _sectionLoop.startSession(
          loopStartMs: profile.loopStartMs!,
          loopEndMs: profile.loopEndMs!,
          isFinite: profile.mode == LoopMode.finiteSection,
          finiteCount: profile.finiteCount ?? 1,
          trackGeneration: generation,
        );
        // Armed only: the song plays from where it normally starts, and the
        // loop takes over when playback reaches the loop start.
        _setMode(profile.mode);
      } else {
        _setMode(LoopMode.off);
      }
      _publishLoopStatus();

      await saveNow();
      if (autoPlay) {
        unawaited(_player.play());
        _recordPlayed(song, generation);
      }
    } catch (_) {
      if (generation != _generation) return;
      _errors.add('Couldn\'t play "${song.title}". The file may be damaged.');
      await _persistence.clear();
      await _resetToIdle();
    }
  }

  Future<void> _onTrackCompleted() async {
    // Ignore a "completed" signal that belongs to a song that is no longer
    // the loaded one (stale callback).
    if (_queueManager.current == null || _loadedGeneration != _generation) {
      return;
    }

    // The song ended while previewing a region at its very end: stop there
    // instead of moving on to the next song.
    if (_preview != null) {
      _finishPreview(pause: true);
      return;
    }

    // 1. If section loop is active, let it handle the completion
    if (_sectionLoop.hasActiveSession) {
      final action = _sectionLoop.onSongCompleted(_generation);
      _publishLoopStatus();
      if (action == SectionLoopAction.seekToStart) {
        final session = _sectionLoop.session;
        if (session != null) {
          final generation = _generation;
          await _player.seek(Duration(milliseconds: session.loopStartMs));
          if (generation != _generation) return; // something newer took over
          unawaited(_player.play());
          return;
        }
      } else if (action == SectionLoopAction.loopCompleted) {
        _setMode(LoopMode.off);
        if (_queueManager.moveToNext()) {
          await _loadCurrentAndPlay();
        } else {
          await _finishQueue();
        }
        return;
      } else {
        // The song ended before the loop ever started: the loop is over.
        _sectionLoop.cancelSession();
        _setMode(LoopMode.off);
        _publishLoopStatus();
      }
    }

    // 2. Otherwise whole-song repeat decides
    final action = _repeat.onSongCompleted();
    _setMode(_repeat.mode);

    if (action == CompletionAction.replay) {
      final generation = _generation;
      await _player.seek(Duration.zero);
      if (generation != _generation) return; // something newer took over
      unawaited(_player.play());
      return;
    }

    if (_queueManager.moveToNext()) {
      await _loadCurrentAndPlay();
    } else {
      await _finishQueue();
    }
  }

  /// Reached the end of the queue: stop on the last song, back at 0:00.
  Future<void> _finishQueue() async {
    await _player.pause();
    await _player.seek(Duration.zero);
    await saveNow(); // remember "last song, 0:00"
  }

  Future<void> _resetToIdle() async {
    _generation++;
    _endRepeat();
    await _player.stop();
    _queueManager.clearCurrent();
    mediaItem.add(null);
  }

  MediaItem _toMediaItem(Song song, {Duration? duration}) {
    final art = song.absoluteArtworkPath;
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: duration ?? (song.durationMs > 0 ? song.duration : null),
      artUri: art == null ? null : Uri.file(art),
    );
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _queueManager.index >= 0 ? _queueManager.index : null,
    );
  }
}
