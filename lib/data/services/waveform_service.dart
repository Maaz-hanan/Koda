import 'dart:io';

import 'package:just_waveform/just_waveform.dart';

import '../../core/storage_paths.dart';
import '../../domain/waveform/waveform_loader.dart';
import '../../domain/waveform/waveform_peaks.dart';
import '../repositories/library_repository.dart';

/// Builds a song's waveform with the just_waveform package and keeps the
/// result on disk ("waveforms/<songId>.wave") so the next open is instant.
/// [PRD FR-026, FR-031]
class WaveformService implements WaveformLoader {
  WaveformService(this._library);

  final LibraryRepository _library;

  /// 100 pixels per second = one value every 10 ms. Plenty for the +/-100 ms
  /// fine adjustment in Phase 4-2.
  static const int _pixelsPerSecond = 100;
  static const int _memoryLimit = 3;

  final Map<String, WaveformPeaks> _memory = {};
  final Map<String, Future<WaveformPeaks>> _inFlight = {};

  @override
  Future<WaveformPeaks> load(
    String songId, {
    void Function(double progress)? onProgress,
  }) {
    final remembered = _memory[songId];
    if (remembered != null) return Future.value(remembered);

    // If the same song is already being processed, wait for that one.
    return _inFlight[songId] ??=
        _loadUncached(songId, onProgress).whenComplete(() {
      _inFlight.remove(songId);
    });
  }

  Future<WaveformPeaks> _loadUncached(
    String songId,
    void Function(double progress)? onProgress,
  ) async {
    final song = await _library.getSong(songId);
    if (song == null) {
      throw WaveformException('This song is no longer in your library.');
    }
    final audio = File(song.absoluteFilePath);
    if (!await audio.exists()) {
      throw WaveformException('The audio file for this song is missing.');
    }

    await StoragePaths.ensureDir('waveforms');
    final cacheFile = File(StoragePaths.resolve(StoragePaths.waveformRelativePath(songId)));

    // 1. Already generated before? Read it back (fast).
    if (await cacheFile.exists()) {
      try {
        final peaks = _toPeaks(await JustWaveform.parse(cacheFile));
        if (peaks.values.isNotEmpty) return _remember(songId, peaks);
      } catch (_) {
        // Damaged cache file: fall through and make a new one.
      }
      await _deleteQuietly(cacheFile);
    }

    // 2. Generate into a temporary file, so a half-written file is never
    //    mistaken for a finished cache.
    final partFile = File('${cacheFile.path}.part');
    await _deleteQuietly(partFile);

    Waveform? result;
    try {
      await for (final progress in JustWaveform.extract(
        audioInFile: audio,
        waveOutFile: partFile,
        zoom: const WaveformZoom.pixelsPerSecond(_pixelsPerSecond),
      )) {
        onProgress?.call(progress.progress);
        if (progress.waveform != null) result = progress.waveform;
      }
    } catch (_) {
      await _deleteQuietly(partFile);
      throw WaveformException("Couldn't read this audio file to draw its waveform.");
    }

    if (result == null) {
      await _deleteQuietly(partFile);
      throw WaveformException("Couldn't draw a waveform for this song.");
    }

    final peaks = _toPeaks(result);
    if (peaks.values.isEmpty) {
      await _deleteQuietly(partFile);
      throw WaveformException("Couldn't draw a waveform for this song.");
    }

    // 3. Keep it for next time.
    try {
      await partFile.rename(cacheFile.path);
    } catch (_) {
      await _deleteQuietly(partFile);
    }
    return _remember(songId, peaks);
  }

  WaveformPeaks _remember(String songId, WaveformPeaks peaks) {
    if (_memory.length >= _memoryLimit) _memory.remove(_memory.keys.first);
    _memory[songId] = peaks;
    return peaks;
  }

  /// just_waveform data -> our package-independent [WaveformPeaks].
  /// Each pixel has a min and max sample; we keep whichever is louder.
  /// `flags & 1` means 8-bit samples (range 128), otherwise 16-bit (32768).
  static WaveformPeaks _toPeaks(Waveform w) {
    final fullScale = (w.flags & 1) == 1 ? 128.0 : 32768.0;
    final values = List<double>.generate(w.length, (i) {
      final high = w.getPixelMax(i).abs();
      final low = w.getPixelMin(i).abs();
      final loudest = high > low ? high : low;
      return (loudest / fullScale).clamp(0.0, 1.0).toDouble();
    }, growable: false);

    final perSecond =
        w.samplesPerPixel > 0 ? w.sampleRate / w.samplesPerPixel : 100.0;
    return WaveformPeaks(values: values, peaksPerSecond: perSecond);
  }

  Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
