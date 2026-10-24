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
}
