import '../database/loop_profile_dao.dart';
import '../models/loop_profile.dart';

class LoopProfileRepository {
  LoopProfileRepository(this._dao);

  final LoopProfileDao _dao;

  /// The saved profile, or null if this song was never configured.
  Future<LoopProfile?> findProfile(String songId) => _dao.getBySongId(songId);

  /// The saved profile, or a "looping off" default. Never null.
  Future<LoopProfile> getProfile(String songId) async =>
      await _dao.getBySongId(songId) ?? LoopProfile.defaultFor(songId);

  Future<void> saveProfile(LoopProfile profile) => _dao.upsert(profile);

  Future<void> deleteProfile(String songId) => _dao.delete(songId);
}
