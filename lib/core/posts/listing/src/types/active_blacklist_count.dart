/// Count posts hidden by enabled rules, not rule matches. A post can match
/// several rules; disabled rules must not keep its hidden count inflated.
int countActiveBlacklistPosts<T>(
  Map<String, Set<T>> matches,
  Map<String, bool> activeRules,
) => {
  for (final entry in matches.entries)
    if (activeRules[entry.key] ?? false) ...entry.value,
}.length;
