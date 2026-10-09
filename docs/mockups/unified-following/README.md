# Unified pinned searches and Following

Interactive design prototype, based on `develop` at
`f4972eb54119fce98360c4c2303bbce375b8e722`. No Flutter application code is changed.
The proposed behavior is not an assertion about functionality already shipped.

## Open the prototype

Open `index.html` in a modern browser. It is a single, self-contained file: no
build, packages, server, fonts, images, APIs, or accounts are needed. For browsers
that restrict local files, serve this directory with `python -m http.server 8000`
and open the local server instead.

Changes are kept under the isolated local-storage key
`boorusama.unified-following.mockup.v1`. The prototype never reads or changes real
Boorusama data. When storage is unavailable, it remains usable in memory. Use
**Design notes -> Reset demo** to restore the fixtures. All artwork and search
results are synthetic; new queries generate illustrative results, not real API
responses. Profile names identify simulated sources, not connected accounts.

## Recommendation and vocabulary

Retain **Pinned searches** for the existing feature and use **Following** as the
browsing destination. Do not use **Saved searches**, which conflicts with the
separate Danbooru feature.

| Term or action | Meaning |
| --- | --- |
| Pinned search | One reusable query bound to one profile. |
| Search folder | References to searches and nested folders. A search may be linked to several folders. |
| Following | The place to open the feeds the user has created. |
| Create feed | Make a folder's Posts view directly available in Following. No copied searches or converted folder type. |
| Follow | Pin or reuse an artist/tag/query and link it to one or more feed folders. |
| Posts / Searches | Two views of the same folder, not separate management systems. |

**Search library** is a reasonable alternative if the existing name is changed:
it describes the shared collection better than “Pins,” but loses familiar
terminology. **Streams** is compact but less explicit about following interests.
**Watchlist** suggests monitoring/alerts more than browsing. These alternatives
are included in the prototype's Design notes, not adopted as competing labels.

The feed and folder intentionally share their name. Creating the same feed twice
is not offered. Removing a feed only removes its entry from Following; the folder
and all searches remain. “Remove from this folder” removes a reference;
“Delete everywhere” is a separate, confirmed operation.

## Walkthrough

1. Open **Daily inspiration**. Posts combine Danbooru, Gelbooru, and Rule34.
   Filter by profile or reverse upload order. Post `101` exists on three sites:
   those are three different posts. Open the Danbooru post to see that two search
   matches on that one site are combined.
2. Switch to **Searches**. The **Landscapes** subfolder contributes searches to
   the parent Posts view. Open it through the same hierarchy used by the library.
3. Edit **Mosslight** from its overflow menu. Change its name or query; then open
   **Color & form** or **Pinned searches -> All searches**. The same definition
   changes everywhere. Query changes replace this source's synthetic results.
4. Use **Add existing** or **Follow**. Following `gesture_drawing` on Gelbooru
   reuses the already-pinned **Gesture studies** record instead of copying it.
5. Use **Create feed -> Reference board**. The existing folder immediately gains
   an entry in Following. Remove that feed and verify its folder/search survives.
6. Create a new empty feed, add a search, create a subfolder, or rename its folder.
   Long-press a search or use its menu to select. Shift-click extends a range;
   pointer drag after a long press also selects a range. Bulk linking and removing
   references are available in the contextual toolbar, without a permanent
   selection-mode button.
7. Switch to **Gelbooru offline** in the prototype toolbar. The error is scoped
   to that source, cached content remains visible, and **Retry** recovers the
   simulated state. Try the phone preview and light theme as well.

## Why mixed profiles require changes, but are feasible

The inspected implementation has real single-profile assumptions; the restriction
is not merely a future Gelbooru optimization:

- [`SearchFollowingFeed`](../../../lib/core/search/subscriptions/src/types/search_following_feed.dart)
  requires one `profileId`. Its merge indexes cached posts by numeric post ID.
- [`HiveSearchSubscriptionRepository.saveFeed`](../../../lib/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart)
  creates/reuses sources under the supplied profile. Existing feed sources are
  distinguished from ordinary pinned searches. Deleting a feed may delete sources
  not referenced by another feed; this is unsafe for shared pinned searches.
- [`_CachedFeedGrid._createHistory`](../../../lib/core/search/subscriptions/src/pages/following_feeds_page.dart)
  selects the adapter and post repository using the feed's `widget.config`, not
  each source's profile. The page also provides a single current-profile scope.
  Thumbnail configuration already resolves individual post origins, so some
  origin-aware infrastructure is available.
- [`FeedHistorySession`](../../../lib/core/search/subscriptions/src/services/feed_history_session.dart)
  uses `Set<int>` for deduplication. It filters out posts without timestamps and
  rethrows a source-page failure after its workers finish.

For production, keep the search's profile but remove profile ownership from the
feed definition. Resolve the adapter, authentication, pagination, and post
presentation from each source/post origin. Use canonical site/instance + post ID
for identity, not bare ID. Preserve the profile context needed to perform actions;
profiles on the same site should not automatically produce duplicate posts.
Cross-site copies with different origins remain separate unless an independent,
explicit content-matching feature is designed.

Merge streams by actual upload time with a stable tie-breaker. Unknown dates need
an explicit fallback/section rather than silent dropping or comparison of IDs
across unrelated sites. Isolate partial failures and retries per source; keep
shared host/account request limits, cancellation, and stale-result protection.
Do not imply that a chronological feed is complete when one source could not load.
The mockup's fixture list is finite and does not implement network pagination.

Gelbooru batching can be omitted initially. It is not inherently incompatible
with mixed feeds: a later optimizer could batch eligible queries within one
site/profile and merge that batch with other sources. Do not sacrifice source
correctness or hide other profiles merely to retain batching.

## Data and migration boundaries

Use one canonical search record per profile/query identity and folder membership
references. The same membership drives both folder views. Descendant searches
are included, with repeated references deduplicated. Query edits must invalidate
all affected feed results even when the list of source IDs did not change.

The prototype represents the feed entry with a boolean on the folder. Production
can retain a separate `FeedDefinition(folderId)` and feed runtime/cache; sharing
management does not mean putting network machinery into the folder model.

A migration must preserve existing feed names, searches, profile bindings, and
references, then expose those searches in the pinned library. Reconcile duplicate
records deliberately; do not silently overwrite conflicting user names or reset
all update state. Update backup/import/export, profile removal, query-edit
invalidation, and deletion rules together. No implicit orphan collection should
delete an original pinned search just because its last feed was removed.

## UI boundaries and intentional prototype simplifications

Cards, overflow actions, long-press selection, profile metadata, folder badges,
and shared editing follow the inspected pinned-search/feed screens. The theme is
an approximation of adaptive Material-style colors, not a new Flutter theme.
Actual implementation should reuse the existing cards, folder-tree picker,
selection widgets, localized strings, and Kurumi popup components.

The two-entry navigation is a context for this concept, not a redesign of the
entire application sidebar. The explanatory cards and upper prototype toolbar
help evaluate the design; they do not all need to ship. The optional display name
and query editor deliberately remain the same from library and feed management.

Folder selection/moving, source pause policies, auto-refresh scheduling,
background fetches, production read/unread semantics, account deletion, and
migration execution are not implemented. The mockup shares “seen” flags by post
identity and marks all loaded results of the chosen profile filter, not just the
cards currently inside the viewport. A production feed's read cursor requires
its own decision. Opening Searches does not automatically mark posts as read.

## Checks and limitations

Run `python test_mockup.py` with Playwright and Chromium installed. The test runner
uses a system Chromium when available; set `CHROMIUM_PATH` for another executable,
or install Playwright's Chromium. It renders the local HTML in memory and uses an
isolated storage double, so the test does not need a server or network access.

The 18 browser checks cover shared edits, identity/deduplication, mixed profiles,
ordering, reuse, existing/new feed creation, safe removal/deletion, long-press and
Shift selection, outside-click dismissal, cancellation, partial failure, nested
folders, storage serialization/restoration, safe text rendering, and constrained
layouts. Narrow layouts were exercised at 320/390 px, text enlargement at 150%,
and a reduced 390 x 420 viewport to approximate keyboard constraints. These are
not real Android keyboard or touch-device acceptance tests. Native filesystem
loading and real local-storage persistence could not be exercised by this
sandbox's managed browser; in-memory rendering and the storage round trip were
checked instead.

The full repository verification required by `AGENTS.md` remains **unrun**:
this environment has no FVM/Flutter SDK or full local checkout, and direct Git
clone access is unavailable. App, package, CLI, and repository-tooling suites are
therefore not claimed as passing. No application implementation, migration, or
release readiness is implied by the prototype checks.
