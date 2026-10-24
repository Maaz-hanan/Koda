import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/loop/loop_mode.dart';
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

/// Playback problems to show to the user.
final playbackErrorProvider = StreamProvider<String>(
  (ref) => ref.watch(audioHandlerProvider).errors,
);
