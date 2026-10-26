import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/waveform_service.dart';
import '../domain/waveform/waveform_loader.dart';
import 'repository_providers.dart';

/// Makes (and caches) song waveforms. Tests replace this with a fake.
final waveformLoaderProvider = Provider<WaveformLoader>(
  (ref) => WaveformService(ref.watch(libraryRepositoryProvider)),
);
