String allocatePinnedFolderCopyName(String name, Set<String> reservedNames) {
  final base = name.trim();
  var candidate = base;
  var suffix = 2;
  while (!reservedNames.add(candidate.toLowerCase())) {
    candidate = '$base ($suffix)';
    suffix++;
  }
  return candidate;
}
