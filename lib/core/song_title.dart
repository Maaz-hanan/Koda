/// The longest song title we keep.
const int kMaxSongTitleLength = 200;

/// Cleans a title typed by the user: trims it and turns any run of spaces,
/// tabs or line breaks into one space. Returns null when nothing is left
/// (an empty title is not allowed). Longer titles are cut at
/// [kMaxSongTitleLength].
String? cleanSongTitle(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return null;
  if (cleaned.length <= kMaxSongTitleLength) return cleaned;
  return cleaned.substring(0, kMaxSongTitleLength).trim();
}
