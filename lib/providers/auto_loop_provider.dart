import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/auto_loop_service.dart';
import '../domain/autoloop/auto_loop_runner.dart';
import 'waveform_provider.dart';

/// Runs Auto Loop for a song. Tests replace this with a fake (like
/// waveformLoaderProvider), so no real analysis or isolate is needed.
final autoLoopRunnerProvider = Provider<AutoLoopRunner>(
  (ref) => AutoLoopService(ref.watch(waveformLoaderProvider)),
);
