# #166 — Profile-independent Bookmark reads and stable Related/Pool covers

**Date:** 2026-11-18

**Task branch:** bug/166-pool-bookmark-covers

**Reviewed branch HEAD:** 38363a2c1f0f38339ea74859a6678179a366acd8

**Related review handoff:** [2026-11-17-pre-release-review-remediation.md](https://github.com/timberpile/Boorusama/blob/maintenance/pre-release-bugfix-preview-20261117/docs/handoffs/2026-11-17-pre-release-review-remediation.md)

## 1. Binding owner decisions (supersede earlier suggestions)

Implement the user's observed regressions and the accepted Reader/Cover behavior. These decisions override any contradictory #166 advice in earlier handoffs or agent plans.

- **A Bookmark identifies a source and content, not an owning account.** A saved originating-profile hint is never a mandatory condition for opening, thumbnails, mosaics, availability, manual metadata refresh or retries. Prefer the **first compatible saved local profile in persisted profile order** for the same engine and exact source namespace/installation. Otherwise use an **already registered, permitted anonymous reader**. Do not create a dummy persistent profile, select a profile for a different source, or silently try another actor after an HTTP failure.
- **MiteMite has not shipped.** Remove local profile hints from its outgoing Bookmark packages. No protocol migration or republish workaround for *unreleased* MiteMite snapshots is required. Current receiver must be able to read a pre-existing received bookmark bearing a foreign hint without requiring resubscription. Do not rewrite publisher-owned received records.
- **Existing covers are sticky.** Once an eligible cover is chosen, keep that chosen image; do NOT automatically select another image merely because profiles, blacklist, rating, visibility preferences, local account order or the policy hash change. A local policy may still **suppress display** of a forbidden or unverified cover; it must not rewrite/reselect the saved cover as a side effect.
- **Update cover selection only when the relevant *content group's member ordering* changes**, e.g. changing a saved Related family's oldest/newest ordering or an explicit source-group refresh that establishes a different member order. Do not treat the containing Bookmark Group's tile sort, global timeline sort, profile reorder or filtering as a member-order change. No polling/reindex just to keep covers recent.
- **Legacy development-branch states are not a compatibility target.** Do not add migrations for intermediate, unreleased v6-v10 Bookmark/MiteMite formats, or compatibility code merely to preserve unpublished test data. Do not delete the actual shipped user's data or damage support for previously publicly released bookmark formats; production migration policy is a **separate pending owner discussion** and is NOT to be designed/implemented in this task.

Expected user outcomes: a subscribed MiteMite Series Pool opens and has a permitted cover even without the publisher's profile; locally saved Related families obtain and retain covers.

## 2. Root causes in current code

- `lib/core/bookmarks/src/providers/pool_bookmark_provider.dart`: `resolvePoolBookmarkProfile` insists on the original hint via `PostOriginResolver(...allowProfileHintFallback: false)` and returns null for a Related with no hint. `eligiblePoolCover` additionally requires `post.origin.profileIdHint == config.id`, rejecting cached posts from a different device/profile.
- `lib/core/bookmarks/src/widgets/bookmark_group_viewer_entry.dart`: `bookmarkGroupReference` consults that strict resolver even though native `CollectionBookmark.sourceSite` often already proves the full source URI. `groupViewerEntryForBookmark` subsequently binds using `bindViewerOrigin` with hint-sensitive account selection. A null reference produces `UnavailableGroupViewerEntry`.
- `lib/core/content/content_access_provider.dart`: `contentAccessForReferenceProvider`/ForOrigin use the generic Post resolver and can return `AmbiguousPostOrigin` rather than the first saved compatible profile; they are not Bookmark-specific and should not be casually changed for all live listing/server-action requests.
- `lib/core/bookmarks/src/widgets/bookmark_pool_card.dart`: `BookmarkPoolCoverImage` passes the saved hint back to generic access, excludes Related from recovery and only displays persisted covers when `displayed.coverPolicy == currentPolicy`. A policy hash change currently hides the same stored cover, even when the image remains allowed.
- `lib/core/bookmarks/src/providers/related_bookmark_provider.dart`: `relatedBookmarkDraftProvider` creates a new Related without a cover; `relatedBookmarkRefreshProvider` can discover one via `RelatedFamilyReference.query` = `parent:<anchor>` and `family.contains` but is not wired into initial save/backfill. `missingPoolCoverProvider` and `scheduleMissingPoolCover` explicitly skip Related.
- `lib/core/bookmarks/src/services/bookmark_library_service.dart`: `setRelatedOrder` changes `RelatedBookmark.preferredOrder` alone, with no explicit order-driven cover selection. `RelatedPostsOrder.queryOrder` is `order:id_asc` or `order:id_desc`.
- `lib/core/backups/mitemite/bookmark_package.dart`: `SyncBookmarkPackageBuilder.build` serializes `codec.encode(data)`. `StoredBookmarkCodec.encodeForTransfer` can include canonical `profileIdHint`/native `sourceProfileHint`; `syncBookmarkSemanticHash` already disregards these fields, so hint-only sanitization need not start a new MiteMite revision.

Confirm these source paths on the **latest** #166 worktree before editing; the branch has already received earlier fixes for typed Pool cover patches, bounded retry, and received-only presentation covers. Preserve them.

## 3. Bookmark Reader selection: one shared, safe contract

Create or reuse a small **Bookmark-specific Reader resolver**, with a pure source/profile selection function plus a Riverpod wrapper for current auth/policy. Apply it consistently to saved **Posts, Pool/Series, Related and native Content Groups** and all their visibility, cover, viewer, retry and manual-refresh consumers. Avoid changing general PostOriginResolver semantics used by Following Topics, current searches, live requests, mutations, downloads or unbound posts.

Inputs: saved proven ContentReference/site URI when present, otherwise source namespace + engine from PostOrigin; current profile list in **persisted order** (inspect `orderedProfileConfigsProvider`, do not assume raw booruConfigProvider order); current registered anonymous-source policy.

Selection:
1. Validate engine and exact site/installation, including host, port, installation path, and full proven URI when available. Never use a same-host profile with a different site path or unsafe HTTP/HTTPS substitution. Never infer an HTTPS URL from a legacy host-only key.
2. Pick the first matching current profile from the **saved ordering**, **regardless of saved foreign/stale/null profile hints**. Select only a usable current ContentAccessContext; fail closed while its policy is loading/invalid. Honor effective blacklist/rating/visibility settings of that reader.
3. If no matching configured profile exists, use the existing `AnonymousSourcePolicy.resolve(engine, site)` for a proven URI or `forNamespace(engine, namespace)` for a registered canonical legacy namespace, and require a registered Group/Post engine adapter. Explicit allowlist, API/media hosts, transport and blacklist guards remain mandatory. An auth-required or unknown site remains unavailable without a correct local profile. No broad engine-wide anonymous fallback.
4. Return the actual actor/context and immutable ViewerSourceBinding. A fresh open after changing saved profile order may select a different reader; a currently open viewer or in-flight network request must **stay pinned** and be revoked/canceled if its auth or policy changes, not transparently swapped.
5. Do not attempt automatic account cycling or anonymous downgrade upon an API error. Source/availability should distinguish **unsupported/no authenticated reader**, **network/API load failed**, and **filtered/unavailable content** instead of claiming the content belongs to an absent “originating profile.”

**Concrete consumers to audit and align:** `bookmarkGroupReference`, `groupViewerEntryForBookmark`, `BookmarkPoolCoverImage`, `BookmarkNativeGroupCover` and nativeGroupViewerEntryForBookmark, `BookmarkPoolCard._refresh` and related refresh actions, `resolvePoolBookmarkProfile`/ `resolveBookmarkOriginProfile`, `contentAccessForReferenceProvider` uses from saved Bookmarks, `bindViewerOrigin` uses from saved Bookmark entries, `bookmarkProfileAvailabilityProvider`, `BookmarkScrollView` / bookmark mosaics and Post media presentation. The outer Bookmark's source is not permission for unrelated server mutations/background downloads.

**Critical distinction:** derive a valid `ContentReference` from a native saved `sourceSite` without demanding the original account. For an old record lacking an installation URI, require a real matching local profile or explicitly registered public endpoint; never guess a URL. Source resolution and actor selection must agree so a cover cannot appear available while the same entry fails to open.

## 4. Remove profile hints from *MiteMite outgoing data only*

Sanitize the outgoing materialized transfer representation (or detached copy) in `SyncBookmarkPackageBuilder.build` / the specific MiteMite package layer **before signing**. Remove local-source references at all applicable wire locations:
- Post/Legacy Group nested `origin.profileIdHint`;
- native `ContentGroupBookmark.sourceProfileHint`;
- any other local-only profile locator included by the existing transfer encoder.

Retain engine, source namespace/site URI, upstream IDs, reference keys, opaque Post facts, media metadata, membership, timestamps and all non-sensitive content identity. Keep signatures, canonical hashing, duplicate detection, source revision identity, replay/ownership guards unchanged. Do **not** mutate local saved records to strip hints and do **not** globally change backup/import codec behavior without a separate reason: personal backup compatibility is distinct from MiteMite publication.

Because MiteMite is unpublished, do NOT add a protocol-version migration, forced catalog revision or special “old subscriber” workaround solely to trigger republishing after stripping hints. But **incoming existing foreign-hint records must already work** through the reader fix; tests should not depend on new publication to hide the issue. Update MiteMite documentation to match.

## 5. Covers: selection, policy and ordered refresh

**Stable selection:** A selected cover is a saved presentation choice, not a rolling recommendation. Do not run `PoolSummaryIndexer`, replace a cover, or invalidate its identity merely on profile/order-of-profiles/blacklist/rating changes. Do not use `coverPolicy == currentPolicy` as the condition that the stored choice *exists*. Separate **cover identity** from **permission to render now**. If the chosen cover is currently disallowed, show a restricted/neutral placeholder without selecting a different member and without overwriting/deleting the saved cover. It may become visible again if policy permits. If visibility facts are insufficient, fail closed rather than leak media. Prefer native `GroupCover.visibility` / `GroupCoverVisibility` and current access policy, adding narrowly scoped selection facts to fresh records only if needed. Never blindly render raw URLs. The current `PoolBookmarkCover` stores variants/URLs only; inspect how to apply per-cover policy without an unconditional stored-digest equality gate.

**Initial Pool/Related selection:** When a new remote reference is saved, try already-loaded, **source-verified** eligible members (at most 40, static thumbnail, family membership proven, actor's current visibility policy). Remove the false `post.origin.profileIdHint == config.id` constraint from eligiblePoolCover and equivalent new code. Ensure eligibility checks engine/installation/current Reader and policy. Saving/picker opening must not wait for a remote crawl or count query. If no cached eligible member, persist reference promptly and initiate **bounded async cover discovery** later; only missing-cover bookmarks are candidates. Existing blank imported/received Bookmarks should also get a cover opportunistically on visibility. Related must use its own `RelatedFamilyReference.query`/`family.contains` path, **not** `pool:<anchorId>`. Support source-appropriate oldest/newest selection, with no fabricated “complete” coverage on partial metadata. Never use a Page of another family or a cross-site member as cover.

**Changes in *member order*:** An explicit saved Related `setRelatedOrder(bookmarkId, order)` change is a trigger for one bounded reselection based on `RelatedPostsOrder.queryOrder`, with async fetch outside the shared journal and revalidation before the atomic cover+preference update (or safe two-stage commit). Preserve bookmarked Related order, ID, membership timestamps, native `GroupBookmarkIndex`, details and ownership on failed/stale lookup. If order changes twice while lookup is pending, the late response must not overwrite the newer choice. A source Pool's explicitly refreshed, verified member order may update its cover if this truly changes cover selection; do not poll merely to detect changes. Different ordering of *local Bookmark Group cards* is **not** a trigger.

**Received Bookmarks:** Retain the branch's source-ownership protection. For received-only (and any mixed local/received membership requiring it), use the existing **receiver-local, access/source-revision-scoped presentation cover** rather than rewriting a publisher-owned payload. Keep idempotent frozen snapshots, source digests, read states, checksums/checkpoints and membership dates intact. On Forget/withdrawal/revocation or changed actor, discard presentation cache appropriately. Stable chosen cover semantics should apply to that receiver-local choice as well.

**Rate limits:** Keep existing one-job-at-a-time serialized queue, in-flight deduplication, bounded cooldown/caching and 40-member/metadata budget; no entire-series crawl. Do not retry forever on rebuild or translate a temporary network failure into “definitely no eligible cover”.

## 6. Tests and acceptance evidence

Add **failing-before and passing-after tests** for:
- Real MiteMite publication/receive into a device with no matching publisher profile: saved Pool/Series opens and its selected cover displays through the permitted public reader; same foreign hint in an **already received** record still works without republish.
- Zero/one/multiple compatible profiles: saved profile order determines fresh reader; stale/foreign/null hint ignored; different installation path, engine or full site URI never matches; no matching auth-required source fails cleanly; an allowed public source works without any local profile. Source errors are actionable, not “originating profile” false positives.
- Saved Post, Series/Pool, Related and native Group: availability, cover, viewer and refresh select the *same* actor; changing profile order affects fresh opens only, not an open viewer. Revocation/auth/policy changes cancel/deny stale work. Unsupported public sources and unrelated CDN access remain denied.
- MiteMite signed outbound payload has **no local profile hint** (Post, Legacy Group, native Group) while content IDs and group data remain intact. Signing/semantic hashing and receive validation remain consistent.
- New locally saved Related immediately uses a permitted cached static member with zero network requests; otherwise asynchronous `parent:<anchor>` discovery fills missing cover after save/restart. Correct family membership, partial result, multi-profile, no profile where allowed, blacklist/rating and deleted/animated exclusions. No duplicate work on rebuild.
- A chosen cover is unchanged (identity and persisted bytes) after profile reorder, blacklist/rating changes, app restart, unrelated Bookmark-group sort and failed refresh. Its **display** is suppressed if current policy truly disallows it, without replacing it. Restoring permission reveals the same selected image.
- Changing saved Related oldest/newest member order updates the cover once with correct source ordering; pending stale fetch cannot undo a later sort. Failed lookup cannot erase a previously selected cover or change unrelated metadata. Test explicit Pool order refresh only where supported.
- Real unified Hive journal/rollback and mirror ownership: local cover patch preserves native sourceGroup index/tags/coverage/details, Related preferredOrder, records, memberships and dates; received-only cover stays receiver-local and does not mutate signed publisher-owned records; Forget clears local presentation state. Follow earlier #166 review corrections already on branch.

Run the relevant Bookmark/MiteMite/Group/Related/anonymous-access and Viewer suites, including `test/core/bookmarks/pool_cover_backfill_test.dart`, `test/core/bookmarks/pool_bookmark_source_policy_test.dart`, `test/core/bookmarks/pool_bookmark_refresh_failure_test.dart`, real Hive mirror/transfer tests, and application widget flows. Then run the complete `./scripts/run_regression_tests.sh` on the final integrated **bugfix preview** candidate because the Reader change crosses core domains. Format Dart, analyze all changed code, check `git diff --check`; report exact commands, exit codes, test counts and final runtime SHA. Device/live tests are separate and require authorization; do not claim them if not run.

## 7. Delivery and boundaries

1. Fetch origin and check current HEAD/worktrees; read `AGENTS.md`, `docs/development_workflow.md` and the applicable debug/execute-plan/verify skills.
2. Continue **bug/166-pool-bookmark-covers**, preserving the earlier #166 fixes from HEAD 38363a2. Add focused tests and implement the coherent code correction. If requirements reveal a real prerequisite outside #166, document that instead of silently rewriting an unrelated task branch.
3. Review diff independently if available; fix concrete review findings. Commit and push the #166 branch with `Refs #166`.
4. After passing branch verification, replay the verified changes into the **existing** `maintenance/pre-release-bugfix-preview-20261117` branch (current HEAD must be rechecked; previously 695cd84625b8fba0934b231522b65895139a0558), retaining the other ten bugfixes and no independent feature #170. Verify combined source/replay patch ancestry and full suite. Keep new transfer format work inside the unpublished #166/MiteMite scope.
5. Provide a concise result by symptom with before/after tests, affected code, chosen Reader rules, sticky-cover behavior, branch SHA, preview SHA, and outstanding Android/live acceptance.

**Do not** merge into `develop`/`master`, create a PR, close issues, remove branches/worktrees, or execute a release. **Do not** start the general release/migration-policy audit or replace published storage compatibility here. That topic is reserved for a separate owner discussion.