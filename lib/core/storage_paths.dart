import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/models/song.dart';

/// Turns the SHORT paths stored in the database (e.g. "music/abc.mp3")
/// into full paths on disk.
///
/// Why: on iOS the app's Documents folder location can change after an app
/// update or reinstall. If we stored full paths, songs would "disappear".
/// Short paths + this helper always work.
class StoragePaths {
  StoragePaths._();

  static String? _docsPath;

  /// Call once at startup, before runApp.
  static Future<void> init() async {
    _docsPath = (await getApplicationDocumentsDirectory()).path;
  }

  static String get _docs {
    final d = _docsPath;
    if (d == null) {
      throw StateError('StoragePaths.init() must be called before use.');
    }
    return d;
  }

  /// Short path -> full path. Paths that are already absolute pass through.
  static String resolve(String stored) =>
      p.isAbsolute(stored) ? stored : p.join(_docs, stored);

  /// Makes sure a folder inside Documents exists (e.g. "music") and returns it.
  static Future<Directory> ensureDir(String relative) async {
    final dir = Directory(p.join(_docs, relative));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

extension SongPaths on Song {
  /// Full on-disk path of the audio file.
  String get absoluteFilePath => StoragePaths.resolve(filePath);

  /// Full on-disk path of the artwork image, or null.
  String? get absoluteArtworkPath {
    final a = artworkPath;
    return a == null ? null : StoragePaths.resolve(a);
  }
}
