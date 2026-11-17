# Sort Following Topics by Added Date — Technical Handoff

Issue: [#170](https://github.com/timberpile/Boorusama/issues/170)
Source reviewed: [`develop` at `55cec5ae2b69`](https://github.com/timberpile/Boorusama/tree/55cec5ae2b697612a68af40ed3a8bc4ba1caedbb) (2026-11-17).
Audience: local implementation agent. Code snippets are **unapplied proposals**, not verified patches.

## Evidence

**Source-confirmed:** `lib/core/search/following_topics/src/types/following_topic.dart` defines required `FollowingTopic.createdAt`, set by `FollowingTopic.create`; no new storage field is necessary. Prior source review found no Added At option in the existing topic sort controls. Locate the current sort enum/comparator and persisted sort preference in the local agent's checkout before applying this sketch.

## Suggested implementation

Extend the *topic list* sorting options (not feed post ordering) with two explicit choices, such as `addedNewest` and `addedOldest`. Compare `createdAt`, then use existing `position` and stable `id` to break ties; preserve existing manual order and folders.

```dart
int compareAddedAt(FollowingTopic a, FollowingTopic b, {required bool newest}) {
  final date = newest
      ? b.createdAt.compareTo(a.createdAt)
      : a.createdAt.compareTo(b.createdAt);
  if (date != 0) return date;
  final position = a.position.compareTo(b.position);
  return position != 0 ? position : a.id.compareTo(b.id);
}
```

Add the relevant localized labels and wire selection persistence through the existing sorter. **Do not use `lastMaterialEditAt` or `lastSuccessfulCheckAt`**: neither represents the time a topic was added. Existing records already carry creation dates; no migration or backfill should be invented.

## Focused verification

- Three topics with nonmonotonic position and timestamps sort correctly in both directions.
- Equal dates use deterministic ties, folder-scoped list changes do not affect another folder, manual order remains available.
- Sort selection persists across navigation/app restart if other sorts do, and importing older topics preserves their creation timestamps.
