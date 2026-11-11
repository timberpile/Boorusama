# Bulk Find on Other Profiles

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`. Proposed extension of existing lookup services and nested Bookmark Groups; no matching algorithm or remote favorite mutation should be duplicated.

## Existing reusable services

[ExactPostLookup](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/cross_profile_lookup/src/data/exact_post_lookup.dart) validates original-file MD5, target origin and visibility. It is explicitly limited to supported API-mode sites; it refuses HTML/unsupported engines and responses that ignore the hash predicate. [SharedPixivLookupSession](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/cross_profile_lookup/src/data/shared_pixiv_lookup_session.dart) tries verified source-query variants before optional original hashing, with per-target cursors, cancellation and deduplication. It preserves exact-file versus Pixiv-source match kinds and incomplete coverage.

#119 already covers bulk matching from Pixiv Favorites; #123 covers using the shared artwork lookup from Posts. This request is broader (arbitrary selected Posts and per-profile subgroups), so share the job/result implementation rather than creating a competing Pixiv-only batch engine. #158's unified nested groups supply the destination model.

## Interaction and result shape

Add **Find on Other Profiles** to multi-Post selection. The start sheet shows source count, eligible target profiles in saved order and a destination name; default to all other eligible profiles. The originating profile is excluded per source item, not globally for a mixed-profile selection. Unsupported targets are reported explicitly, not treated as zero matches. Expensive original downloads for hash fallback remain off unless explicitly enabled.

Run a cancellable foreground job with inspected/total progress, matched/unmatched/failed/unavailable counts and retained partial results. Closing a progress surface must not silently discard or restart the job. Present a compact review, then **Save Results** creates:

```
<chosen collection name>
  Source
  <target profile A>
  <target profile B>
```

Source contains every originally selected Post, including unmatched items. Create target subgroups for profiles with saved matches; show zero-match/failed profiles in the result summary rather than creating empty noise. Distinguish duplicate profile names using existing profile identity/display conventions, while keeping subgroup names editable. Do not interpret an existing same-name group as overwrite permission. This is an ordinary local Bookmark hierarchy, not Favorites Sync or a remote Content Group.

## Job and identity rules

Snapshot selected Post references and target access bindings at start. Reuse known verified hashes without downloading media. For Pixiv, coalesce repeated selected pages of the same artwork into a bounded artwork lookup session, but retain page identity and match evidence. Source matches establish artwork association, not exact image-page equality; do not silently label them exact or assign an arbitrary target image to a selected page. Save confirmed source-associated Posts with clear evidence; keep ambiguous candidates reviewable rather than auto-accepting them.

Use a route-independent manual Riverpod job controller and a small bounded queue under existing API bulk admission and host quotas. Do not call the single-Post modal N times, launch N x profiles concurrent futures, or bypass quota coordination. Keep one stateful Pixiv session per artwork; its cursor map must not be reused across unrelated artworks. Share/coalesce requests only when query, source and full access scope agree, not merely because profile URLs match.

Bound pages/results and optional hash bytes per source/target. A budget stop remains incomplete, not 'not found'; preserve continuation for explicit retry. Stop new work on cancellation, discard stale account completions and retain already validated results. A new start uses a new job generation. No persistence/restart queue is needed for the initial feature unless separately requested.

## Saving and compatibility

Save the reviewed hierarchy through the unified Bookmark library mutation boundary, with rollback if group creation or any membership write fails. Reuse semantic identities and existing snapshot-merge rules; the same destination Post may belong to multiple target subgroups without duplicated canonical content or overwritten account-sensitive facts. Preserve Source order where the destination's existing ordering model permits it; do not promise manual group order that the current Bookmark model does not persist. Preserve existing memberships and dates; no deletions, remote favorites or automatic replacing of prior groups.

Cancellation can offer Save Partial Results explicitly. Repeated Save must be guarded against duplicate trees. Existing export/import and backups should work without a new Bookmark schema because the output is normal groups and memberships.

## Verification

Fake-service tests for mixed sites, missing hashes, unsupported profiles, equal names, same-site different accounts, Pixiv multi-page artwork/source-versus-exact evidence, duplicate results, empty pages with continuation, quota admission, cancellation and credential rotation. Mutation tests for partial storage failure and repeat Save. Widget tests for selection -> progress -> review -> group hierarchy. A small authorized live read-only batch validates actual adapters; do not run a large service crawl as an acceptance test. No batch or runtime implementation was executed here.
