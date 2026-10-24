import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' hide LoopMode;

import '../../core/storage_paths.dart';
import '../../data/models/song.dart';
import '../../data/services/playback_persistence.dart';
import '../loop/loop_mode.dart';
import '../loop/whole_song_repeat.dart';
import 'playback_restore.dart';
import 'queue_manager.dart';

/// The ONE owner of the audio player. [PRD §11]
///
/// The screens never touch AudioPlayer. They call methods on this class,
/// and the lock screen / Control Centre / headphones call the same methods
/// (play, pause, skipToNext, ...) through audio_service. So the "Next"
/// rules we write here apply to every source automatically.
///
/// Whole-song repeat (Phase 2) plugs into [_onTrackCompleted] and the
/// track-changing commands; section loops (Phase 3) will use the same spots.
class LoopPlayerAudioHandler extends BaseAudioHandler with SeekHandler {
  LoopPlayerAudioHandler({PlaybackPersistence? persistence})
      : _persistence = persistence ?? PlaybackPersistence() {
    _ready = _init();
  }

  final PlaybackPersistence _persistence;
  final AudioPlayer _player = AudioPlayer();
  final QueueManager _queueManager = QueueManager();

  /// Decides what happens at the end of a song (Off / Once / Infinite).
  final WholeSongRepeat _repeat = WholeSongRepeat();
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

  /// The current whole-song repeat mode, and a stream of changes to it.
  LoopMode get repeatMode => _repeat.mode;
  Stream<LoopMode> get repeatModeStream => _repeatChanges.stream;

  /// Short tap on the Loop button: Off -> Once -> Infinite -> Off.
  void cycleRepeatMode() {
    _repeat.cycle();
    _repeatChanges.add(_repeat.mode);
  }

  /// A different song is about to play, so whole-song repeat ends.
  /// Call this BEFORE any await, so nothing stale can fire in between.
  void _endRepeat() {
    final before = _repeat.mode;
    _repeat.onTrackChange();
    if (before != _repeat.mode) _repeatChanges.add(_repeat.mode);
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

    // Remember where we are whenever playback pauses...
    _player.playingStream.listen((playing) {
      if (!playing) unawaited(saveNow());
    });

    // ...and every 5 seconds while playing, so a kill or crash loses little.
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (_player.playing) unawaited(saveNow());
    });
  }

  // -------------------------------------------------------------------------
  // Our own commands (called by screens)
  // -------------------------------------------------------------------------

  /// Starts playing [songs] from [startIndex].
  Future<void> playQueue(List<Song> songs, int startIndex) async {
    if (songs.isEmpty) return;
    _endRepeat();
    _queueManager.setQueue(songs, startIndex);
    queue.add(songs.map(_toMediaItem).toList());
    await _loadCurrentAndPlay();
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
    if (_queueManager.current == null) return;
    // play() finishes only when playback ends or pauses, so don't await it.
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_queueManager.current == null) return;
    // Next always wins over any repeat. [PRD FR-022, §13 rule 1]
    _endRepeat();
    if (_queueManager.moveToNext()) {
      await _loadCurrentAndPlay();
    } else {
      await _finishQueue();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queueManager.current == null) return;
    // Like most players: if we're a few seconds in, restart the song first.
    if (_player.position > const Duration(seconds: 3) ||
        !_queueManager.hasPrevious) {
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
      await saveNow();
      if (autoPlay) unawaited(_player.play());
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

    final before = _repeat.mode;
    final action = _repeat.onSongCompleted();
    if (before != _repeat.mode) _repeatChanges.add(_repeat.mode);

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
