# Cross-branch findings — AA02/A02

No independent cross-branch finding recorded at initial checkpoint. Add a canonical record here if a confirmed interaction affects multiple targets; reference its stable finding ID from each branch report.

### AA02-A02-F0004 — Mixed-origin PostGrid blacklist conflates equal numeric Post IDs

- Kind / severity / confidence / lifecycle: **defect / medium / static-confirmed / open**.
- Affected branch targets/issues: T014 (`feature/114-timeline-toolbar`, #114; new displayed hidden count), T009 (`feature/107-local-post-sorting`, #107; existing mixed Feed view), and the common PostGrid baseline. **Not introduced by either target branch.**
- Origin: **pre-existing** in the shared PostGrid controller at the observed merge-base `422aeae087c1108e655d85d1a3dac25120456cd6`. Additional contextual heads `5bb52794468b172b7d6878fb825b42b00d654675` (T014) and `7a73544cb79c9f5e3c2337a08140833024a31591` (T009), compared with develop `84df0c2de6cf8fe0177c49babb3fb0eee880f866`.
- Location: `lib/core/posts/listing/src/widgets/post_grid_controller.dart` L604–675, `lib/core/posts/listing/src/types/active_blacklist_count.dart` L1–10; reachable mixed-origin feed `lib/core/search/following_topics/src/pages/topic_feeds_page.dart` around L988–L1009; new display `lib/core/posts/listing/src/widgets/post_grid.dart` L545–L590.
- Source: [pinned filter and counter](https://github.com/timberpile/Boorusama/blob/5bb52794468b172b7d6878fb825b42b00d654675/lib/core/posts/listing/src/widgets/post_grid_controller.dart#L604-L675), [pre-existing baseline version](https://github.com/timberpile/Boorusama/blob/422aeae087c1108e655d85d1a3dac25120456cd6/lib/core/posts/listing/src/widgets/post_grid_controller.dart#L604-L680), [mixed-feed source](https://github.com/timberpile/Boorusama/blob/5bb52794468b172b7d6878fb825b42b00d654675/lib/core/search/following_topics/src/pages/topic_feeds_page.dart#L988-L1009), [new display](https://github.com/timberpile/Boorusama/blob/5bb52794468b172b7d6878fb825b42b00d654675/lib/core/posts/listing/src/widgets/post_grid.dart#L545-L590).

#### Expected versus observed source behavior
The shared PostGrid deliberately supports `DuplicateCheckMode.originAndId`: two posts with the same numeric ID and different source origins are distinct. Blacklist tag matches should be scoped per *Post origin and ID*, not by the bare number. The current `_count` payload carries only `post.id`, `_countInIsolate` builds `Map<rule, Set<int>>`, and `_filterPosts` checks `entry.value.contains(e.id)` for every origin.

#### Trigger and reachable failure path
Create a cached Following Topics Feed with two distinct source profiles/hosts, each returning Post ID 42. Post A has a tag matching the enabled blacklist rule; Post B does not. `_countInIsolate` records `{42}`, then `_filterPosts` excludes **both** A and B. The new timeline-toolbar `countActiveBlacklistPosts` reports **1 hidden** because it unions bare IDs; actual grid loses 2 posts. If both A and B match the rule, both are correctly filtered but the displayed hidden count is still 1 rather than 2. The Feed view's `PostScope<Post>(duplicateCheckMode: DuplicateCheckMode.originAndId)` and source-specific fetches confirm this is a reachable mixed-origin path.

#### Evidence and safeguards checked
The origin-aware duplicate tracker preserves A and B, but blacklist counting and filtering use different, origin-blind identity. The flaw also appears in the baseline pinned controller and is therefore not ascribed to #107 or #114. The added #114 helper merely takes the already-collapsed `Set<int>`, so it cannot correct the missing identity. The current unit test `active_blacklist_count_test.dart` covers overlapping blacklist rules only within one numeric-ID namespace, not cross-host collisions.

#### Root cause / consequences
The source identity is discarded before tag-match aggregation. This can silently hide unrelated posts and make the new compact toolbar's “hidden” count misleading in mixed feeds. These are functional consequences demonstrable from the source path, not observed on a running Android device.

#### Minimal recommended correction
Represent match identities as stable `PostOrigin+postId` keys (or an origin-aware shared identity type consistent with the duplicate tracker) throughout the count payload, `tagCounts`, filtering and displayed hidden-count helper, with transition/typing changes coordinated across consumers. Preserve existing single-source behavior and isolate transferability. Do not simply disable blacklisting for multi-origin feeds.

#### Suggested local verification / regression checks
Build a widget/controller test with posts `siteA#42` matching rule and `siteB#42` not matching. Both initially present; enabled blacklist should remove only A and count exactly 1; disabling restores both. Then test both matching yields count 2, overlapping rules counted only once per full identity, and add siteC with another ID. Verify originAndId deduplication and grouped Feed under real multi-profile data.

#### Assumptions and remaining uncertainty
The source confirms a reachable mismatch when a mixed Feed contains colliding numeric IDs; the incidence/frequency and any downstream blacklist presentation effects have not been measured on device. The issue tracker may already contain a separate work item, but this audit is not authorized to create or modify issues.

#### History
- Cycle 2 2026-10-29T23:23:15.139Z: independently established from common controller, baseline revision, mixed-feed route and new #114 count UI.
