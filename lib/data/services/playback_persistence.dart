import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/playback/playback_restore.dart';

/// Saves and loads [SavedPlayback] using the phone's small key-value store.
/// [PRD FR-011]
///
/// Nothing in here may crash the app: if saving or loading fails, playback
/// just doesn't get remembered.
class PlaybackPersistence {
  PlaybackPersistence({SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _key = 'last_playback_v1';
  static const _volumeKey = 'player_volume_v1';

  Future<void> save(SavedPlayback playback) async {
    try {
      await _prefs.setString(_key, playback.toJsonString());
    } catch (_) {
      // Not remembering the position is better than crashing.
    }
  }

  Future<SavedPlayback?> load() async {
    try {
      return SavedPlayback.tryParse(await _prefs.getString(_key));
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _prefs.remove(_key);
    } catch (_) {}
  }

  Future<void> saveVolume(double volume) async {
    try {
      await _prefs.setDouble(_volumeKey, volume);
    } catch (_) {
      // Not remembering the volume is better than crashing.
    }
  }

  /// The saved volume (0..1), or null when none was saved or it is invalid.
  Future<double?> loadVolume() async {
    try {
      final v = await _prefs.getDouble(_volumeKey);
      if (v == null || v.isNaN) return null;
      return v.clamp(0.0, 1.0).toDouble();
    } catch (_) {
      return null;
    }
  }
}
