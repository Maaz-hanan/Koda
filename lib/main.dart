import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/storage_paths.dart';
import 'data/database/app_database.dart';
import 'data/database/song_dao.dart';
import 'data/repositories/library_repository.dart';
import 'domain/playback/audio_handler.dart';
import 'presentation/library/library_screen.dart';
import 'providers/audio_handler_provider.dart';

// Phase 1C-3: audio engine, mini-player, Now Playing, save/restore last song.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must happen before anything reads or writes song files.
  await StoragePaths.init();

  // Creates the one audio handler and connects it to iOS (lock screen,
  // Control Centre, headphone buttons).
  final handler = await AudioService.init<LoopPlayerAudioHandler>(
    builder: () => LoopPlayerAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.loopPlayer.audio',
      androidNotificationChannelName: 'LoopPlayer Audio',
      androidNotificationOngoing: true,
    ),
  );

  // Put back the last song (paused) at its saved position. Any failure here
  // is ignored: the app just starts with nothing loaded.
  try {
    final library = await LibraryRepository(SongDao(AppDatabase.instance))
        .getSongs();
    await handler.restoreLastSession(library);
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [audioHandlerProvider.overrideWithValue(handler)],
      child: LoopPlayerApp(handler: handler),
    ),
  );
}

class LoopPlayerApp extends StatefulWidget {
  const LoopPlayerApp({super.key, required this.handler});

  final LoopPlayerAudioHandler handler;

  @override
  State<LoopPlayerApp> createState() => _LoopPlayerAppState();
}

class _LoopPlayerAppState extends State<LoopPlayerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Save the position whenever the app leaves the foreground. [PRD FR-011]
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.handler.saveNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoopPlayer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LibraryScreen(),
    );
  }
}
