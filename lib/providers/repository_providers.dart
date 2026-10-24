import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/database/loop_profile_dao.dart';
import '../data/database/song_dao.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/loop_profile_repository.dart';

// Providers are how screens "ask for" shared objects without creating them.

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(SongDao(ref.watch(appDatabaseProvider))),
);

final loopProfileRepositoryProvider = Provider<LoopProfileRepository>(
  (ref) => LoopProfileRepository(LoopProfileDao(ref.watch(appDatabaseProvider))),
);
