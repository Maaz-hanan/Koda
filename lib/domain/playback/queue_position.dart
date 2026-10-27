/// Where the playing song is in the queue: the index of [currentId] in
/// [queueIds], or -1 if nothing is playing or it is not in the queue.
/// [PRD FR-008]
int indexOfSong(List<String> queueIds, String? currentId) {
  if (currentId == null) return -1;
  return queueIds.indexOf(currentId);
}
