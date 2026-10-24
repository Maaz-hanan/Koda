import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/storage_paths.dart';
import '../models/song.dart';
import '../repositories/library_repository.dart';

/// A problem during import, with a message that is safe to show the user.
class ImportException implements Exception {
  ImportException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Copies an audio file into app storage, reads its tags, saves it to the
/// library. [PRD FR-001, FR-002, FR-005]
class ImportService {
  ImportService(this._library);

  final LibraryRepository _library;

  static const supportedExtensions = ['mp3', 'm4a', 'aac', 'wav'];
  static const _uuid = Uuid();

  Future<Song> importFile({
    required String sourcePath,
    required String originalName,
  }) async {
    final ext = p.extension(originalName).toLowerCase().replaceFirst('.', '');
    if (!supportedExtensions.contains(ext)) {
      throw ImportException(
          '"$originalName" is not supported. Use MP3, M4A, AAC or WAV.');
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw ImportException('Could not read "$originalName".');
    }

    final id = _uuid.v4();
    final relAudio = p.join('music', '$id.$ext');
    String? relArtwork;

    try {
      // 1. Copy the audio into app-managed storage.
      await StoragePaths.ensureDir('music');
      final audioFile = File(StoragePaths.resolve(relAudio));
      await source.copy(audioFile.path);

      // 2. Read tags. If this fails we still import, using fallbacks.
      String? title;
      String? artist;
      String? album;
      var durationMs = 0;
      Uint8List? artBytes;
      try {
        final md = readMetadata(audioFile, getImage: true);
        title = _clean(md.title);
        artist = _clean(md.artist);
        album = _clean(md.album);
        durationMs = md.duration?.inMilliseconds ?? 0;
        if (md.pictures.isNotEmpty) artBytes = md.pictures.first.bytes;
      } catch (_) {
        // Untagged or unreadable tags: fall through to the fallbacks below.
      }

      // 3. Save artwork (if any) as its own small file.
      if (artBytes != null && artBytes.isNotEmpty) {
        final isPng = artBytes.length > 3 &&
            artBytes[0] == 0x89 &&
            artBytes[1] == 0x50 &&
            artBytes[2] == 0x4E &&
            artBytes[3] == 0x47;
        relArtwork = p.join('artwork', '$id.${isPng ? 'png' : 'jpg'}');
        await StoragePaths.ensureDir('artwork');
        await File(StoragePaths.resolve(relArtwork)).writeAsBytes(artBytes);
      }

      // 4. Save to the database.
      final song = Song(
        id: id,
        title: title ?? p.basenameWithoutExtension(originalName),
        artist: artist,
        album: album,
        durationMs: durationMs, // 0 = unknown; playback fills it in later
        artworkPath: relArtwork,
        filePath: relAudio,
        importedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _library.addSong(song);
      return song;
    } catch (e) {
      // Don't leave half-imported files behind.
      await _deleteQuietly(StoragePaths.resolve(relAudio));
      if (relArtwork != null) {
        await _deleteQuietly(StoragePaths.resolve(relArtwork));
      }
      if (e is ImportException) rethrow;
      throw ImportException('Could not import "$originalName": $e');
    }
  }

  static String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
