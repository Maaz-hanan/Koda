/// Turns text typed by the user into milliseconds. [PRD FR-014, FR-028]
///
/// Accepted:  "65"  "65.5"  "1:05"  "1:05.5"  "0:00.250"
/// Rejected (null): empty text, letters, negatives, "1:75" (seconds >= 60
/// when minutes are given), more than 3 decimal places.
int? parseLoopTime(String text) {
  final match =
      RegExp(r'^(?:(\d{1,3}):)?(\d{1,5})(?:\.(\d{1,3}))?$').firstMatch(text.trim());
  if (match == null) return null;

  final minutesText = match.group(1);
  final seconds = int.parse(match.group(2)!);
  if (minutesText != null && seconds >= 60) return null;

  final fraction = match.group(3);
  final fractionMs = fraction == null ? 0 : int.parse(fraction.padRight(3, '0'));

  final minutes = minutesText == null ? 0 : int.parse(minutesText);
  return ((minutes * 60) + seconds) * 1000 + fractionMs;
}

/// 65000 -> "1:05", 65500 -> "1:05.5", 65250 -> "1:05.25".
/// Whole seconds have no decimals; otherwise trailing zeros are dropped.
String formatLoopTime(int ms) {
  final safe = ms < 0 ? 0 : ms;
  final totalSeconds = safe ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  final rest = safe % 1000;
  if (rest == 0) return '$minutes:$seconds';
  final fraction = rest.toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '');
  return '$minutes:$seconds.$fraction';
}
