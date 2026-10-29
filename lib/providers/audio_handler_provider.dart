import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/loop_profile.dart';
import '../domain/loop/loop_mode.dart';
import '../domain/loop/loop_status.dart';
import '../domain/playback/audio_handler.dart';

/// The single audio handler. Created in main() and injected there.
final audioHandlerProvider = Provider<LoopPlayerAudioHandler>(
  (ref) => throw UnimplementedError('audioHandlerProvider is set in main()'),
);

/// Play/pause/loading state. UI watches THIS, never the raw player.
final playbackStateProvider = StreamProvider<PlaybackState>(
  (ref) => ref.watch(audioHandlerProvider).playbackState,
);

/// The song that is loaded (null when nothing is).
final currentMediaItemProvider = StreamProvider<MediaItem?>(
  (ref) => ref.watch(audioHandlerProvider).mediaItem,
);

/// Is shuffle on? [PRD FR-008]
class ShuffleNotifier extends Notifier<bool> {
  @override
  bool build() {
    final handler = ref.watch(audioHandlerProvider);
    final sub = handler.shuffleStream.listen((on) => state = on);
    ref.onDispose(sub.cancel);
    return handler.shuffleEnabled;
  }
}

final shuffleProvider =
    NotifierProvider<ShuffleNotifier, bool>(ShuffleNotifier.new);

/// Fires with a song's id each time that song's "last played" time was saved.
final songPlayedProvider = StreamProvider<String>(
  (ref) => ref.watch(audioHandlerProvider).songPlayedStream,
);

/// The songs in the queue, in play order. [PRD FR-008]
final queueProvider = StreamProvider<List<MediaItem>>(
  (ref) => ref.watch(audioHandlerProvider).queue,
);

/// Current playback position, smoothly updated.
final positionProvider = StreamProvider<Duration>(
  (ref) => AudioService.position,
);

/// Whole-song repeat mode (Off / Once / Infinite) for the Loop button.
class RepeatModeNotifier extends Notifier<LoopMode> {
  @override
  LoopMode build() {
    final handler = ref.watch(audioHandlerProvider);
    final sub = handler.repeatModeStream.listen((mode) => state = mode);
    ref.onDispose(sub.cancel);
    return handler.repeatMode;
  }
}

final repeatModeProvider =
    NotifierProvider<RepeatModeNotifier, LoopMode>(RepeatModeNotifier.new);

/// The section loop picture for Now Playing: range, waiting / running and
/// plays left. Null when no section loop is set. [PRD FR-025]
class LoopStatusNotifier extends Notifier<SectionLoopStatus?> {
  @override
  SectionLoopStatus? build() {
    final handler = ref.watch(audioHandlerProvider);
    final sub = handler.loopStatusStream.listen((status) => state = status);
    ref.onDispose(sub.cancel);
    return handler.loopStatus;
  }
}

final loopStatusProvider =
    NotifierProvider<LoopStatusNotifier, SectionLoopStatus?>(
        LoopStatusNotifier.new);

/// Applies a just-saved loop profile to the song that is playing.
/// A separate provider so the editor can be tested without a real player.
final loopProfileApplierProvider =
    Provider<Future<void> Function(LoopProfile)>(
  (ref) => ref.read(audioHandlerProvider).applyLoopProfile,
);

/// Loop-editor Preview. Separate providers (like the applier above) so the
/// editor can be tested without a real player. [PRD FR-029]
final loopPreviewStartProvider = Provider<
    Future<bool> Function(
        {required String songId, required int startMs, required int endMs})>(
  (ref) => ref.read(audioHandlerProvider).previewRegion,
);

final loopPreviewStopProvider = Provider<void Function({bool pause})>(
  (ref) => ref.read(audioHandlerProvider).stopPreview,
);

/// True while a preview is playing.
final loopPreviewingProvider = StreamProvider<bool>(
  (ref) => ref.watch(audioHandlerProvider).previewingStream,
);

/// Playback problems to show to the user.
final playbackErrorProvider = StreamProvider<String>(
  (ref) => ref.watch(audioHandlerProvider).errors,
);
