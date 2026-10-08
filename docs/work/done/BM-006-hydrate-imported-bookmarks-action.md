# Manually hydrate imported bookmarks with native post data

Priority: Normal  
Affected feature: Bookmarks, imported legacy post snapshots, and settings maintenance actions

## Problem and goal

Imported bookmarks, especially those originating from older or external formats such as Anime Boxes, can contain only the shared post data and `LegacyPostData` without the site-specific `BooruPostData`.

When such a bookmark is opened, the existing bookmark recovery path fetches the complete upstream post and replaces the stored snapshot. After that, the bookmark behaves like a natively created bookmark. However, the initial recovery can cause visible layout changes, glitches, or brief stuttering while the viewer switches from the generic fallback presentation to the native site-specific presentation.

Normal users do not need an automatic migration of their complete bookmark library. Instead, provide a deliberately hidden maintenance action that can hydrate all incomplete bookmark snapshots in one explicit batch operation.

## Agreed design and acceptance criteria

- Add a deeply nested advanced maintenance area under `Settings → Data & Storage`. Bookmark hydration should not appear as a prominent normal setting.
- The action must remain accessible in release builds and therefore must not live exclusively inside the current Developer Options, which are only exposed in development environments.
- Provide an action such as `Hydrate bookmark metadata` that processes only bookmarks whose stored post does not yet contain native site-specific payload data. In particular, bookmarks backed by `LegacyPostData` are hydration candidates.
- Bookmarks that already contain complete native post snapshots must not be fetched again.
- Before starting, show how many hydration candidates were found. If none are present, do not start a network operation.
- Before a large batch starts, confirm that the operation can perform network requests against the respective booru sites.
- Resolve the corresponding profile for each candidate through the existing `PostOrigin` / `PostOriginResolver` logic. The batch must not arbitrarily select another profile for the same engine.
- Reuse or extract the existing bookmark recovery logic rather than creating a separate hydration implementation:
  1. fetch the complete post through `originAwarePostRepoProvider(config).getPost(postId)`,
  2. resolve a compatible post-data codec,
  3. upgrade the stored bookmark snapshot while preserving the local bookmark ID and all group memberships.
- A missing or ambiguous profile, missing post ID, unavailable repository or codec, removed upstream post, or individual request failure must not abort the complete batch. Count the affected bookmark as skipped or failed and continue with the remaining candidates.
- Respect existing site-specific rate limiting and request infrastructure. Do not launch thousands of requests through an unbounded `Future.wait()`; concurrency must remain small and controlled.
- If a site requires interactive verification or a CAPTCHA, the maintenance operation must not attempt to bypass it. The affected request may fail or be skipped while processing of unrelated bookmarks continues.
- Show visible progress while the operation is running, including at least `processed / total` and counts for successful, skipped, and failed bookmarks.
- The running operation must be cancellable. Successfully upgraded bookmarks remain persisted when the user cancels.
- Persist each successful snapshot upgrade as processing continues so that cancellation or an app restart loses as little completed work as possible.
- Do not reload or republish the complete `BookmarkLibraryState` after every individual bookmark. The batch path should write successful upgrades directly to the repository and refresh visible library state in batches or once after completion.
- Running the operation again must naturally resume remaining work: bookmarks that were already hydrated are skipped because they now contain native payload data.
- Keep the existing automatic single-bookmark recovery path when an incomplete bookmark is opened. The new maintenance operation is an optional manual optimization and must not become a prerequisite for correct bookmark behavior.
- After completion, show a compact result summary such as `Updated 1832 · Skipped 7 · Failed 3`.
- Localize all user-visible strings.
- Tests must cover at least:
  - candidate detection,
  - already complete snapshots,
  - successful hydration,
  - missing or ambiguous profile resolution,
  - removed upstream posts,
  - individual request failures,
  - resuming after a partially successful previous run,
  - cancellation,
  - preservation of bookmark IDs and group memberships.
- Add coverage proving that the batch does not reload the complete bookmark library after every successful individual upgrade.

## Context and dependencies

The existing single-bookmark recovery path currently lives in the bookmark details flow and uses:

1. `PostOriginResolver` for profile resolution,
2. `originAwarePostRepoProvider(config).getPost(...)` to load the complete post,
3. `BookmarkLibraryNotifier.upgradeBookmarkSnapshot(...)`,
4. `BookmarkLibraryService.upgradeBookmarkSnapshot(...)` for persistent snapshot replacement.

Batch hydration should use the same rules and must not introduce a competing second mechanism for bookmark snapshot upgrades.

`BookmarkLibraryNotifier.upgradeBookmarkSnapshot()` currently republishes the updated library state after a single upgrade. For a batch containing several thousand bookmarks, this method should not be called unchanged inside the inner processing loop. Introduce a batch-oriented service/notifier path that performs substantially fewer full library reloads.

Relevant documentation and code:

- [Repository task queue](../README.md)
- [Post architecture](../../post_architecture.md)
- [Bookmark group behavior](../../bookmark_groups.md)
- [Bookmark details recovery](../../../lib/core/bookmarks/src/pages/bookmark_details_page.dart)
- [Bookmark provider](../../../lib/core/bookmarks/src/providers/bookmark_provider.dart)
- [Bookmark library service](../../../lib/core/bookmarks/src/services/bookmark_library_service.dart)
- [Data & Storage settings](../../../lib/core/settings/src/pages/data_and_storage_page.dart)

Dependencies: None.

Preserve the existing bookmark, snapshot, profile-resolution, request, and rate-limit behavior.

Before implementation, follow the [development workflow](../../development_workflow.md) and [engineering guidelines](../../engineering_guidelines.md). This ticket is unclaimed; implementation requires its own branch/worktree and assigned implementer according to the repository queue rules.

## Decision

2026-10-06: The user chose a manual maintenance action instead of automatic background hydration for imported bookmarks. The action should be placed deep in Settings and explicitly hydrate all remaining incomplete bookmark snapshots. The primary use case is a one-time update of several thousand imported bookmarks. Normal viewer behavior and the existing on-demand bookmark recovery remain unchanged.

## Implementation

Claimed 2026-10-07 by Codex (root session).
Branch: `agent/bm-006-hydrate-bookmarks`.
Worktree: `.worktrees/bm-006-hydrate-bookmarks`.

## Completion evidence

Completed 2026-10-07 in the isolated task worktree.

- Added release-accessible `Settings → Data & Storage → Advanced → Maintenance → Hydrate bookmark metadata`. The page counts incomplete snapshots, confirms site requests, shows progress and outcome counts, and allows cancellation. All new strings use the i18n resources (English base-locale fallback).
- Extracted recovery into `BookmarkRecoveryService`, used by both the existing viewer and the manual batch. It uses the origin-aware post repository and compatible engine codec. Legacy and unknown payloads are candidates; complete native payloads are left alone.
- The batch resolves each origin with `PostOriginResolver`, runs one request at a time, skips unresolved profiles, missing IDs, removed posts and unavailable codecs, and continues after request or write failures. No verification or CAPTCHA bypass was added.
- Each successful update uses the existing library service and is persisted immediately, preserving local IDs, creation time and named memberships. The notifier reloads the library once after completion or cancellation. Runs use the existing exclusive data-mutation queue to prevent concurrent imports/deletions from overwriting batch work; other coordinated data changes wait until the run ends.
- Cancellation finishes and persists the in-flight request before stopping. Already completed snapshots are excluded on subsequent runs. The operation can continue while its page is closed; returning shows progress. An app restart retains completed snapshots but stops the run.
- Verification: 85 tests passed across `bookmark_hydration_test.dart`, `bookmark_maintenance_page_test.dart`, `bookmark_details_page_test.dart`, `bookmark_provider_test.dart`, and `bookmark_library_service_test.dart`. Coverage includes profile hints and ambiguity, native/legacy/unknown detection, missing IDs, removed posts, request/write failures, resume, pre-cancel and in-flight cancellation, persisted IDs/memberships, and exactly one library reload for several successful upgrades.
- Maintenance widget tests exercise confirmation, no candidates, progress, cancellation, and dismissal at 320 px width with 2× text. Keyboard checks are not applicable: this flow has no text input.
- `fvm dart format` applied to changed Dart files; focused Flutter analysis of all eight changed/new Dart files reported no issues; `git diff --check` passed. Required generated outputs were created with `./gen.sh`, followed by `./gen.sh i18n` for the final resources.
- Limitations: no emulator, release APK, live site, rate-limit timing, or interactive CAPTCHA checks were performed. Request infrastructure is reused unchanged. No integration, publication, or remote changes.

## Follow-up: Rule34 failure bursts (2026-10-07)

The user reported many fast hydration failures alongside HTTP 429 in normal browsing. The initial batch was sequential but inherited interactive request defaults; origins without evidenced sustained server rules had no bulk pacing. Recovery also collapsed `RateLimitedError` into a generic failure and immediately attempted every remaining candidate, even when the shared coordinator rejected requests locally during its cooldown. This reproduces rapid failed-count increases without proving that every increase was another network request.

- Maintenance now supplies `ApiRequestClass.bulkTransfer`, disables cooldown replay, and prevents queued requests from starting after cancellation. Successfully completed in-flight upgrades are still persisted.
- The existing coordinator applies conservative application pacing of one bulk start per 1.25 seconds at each actual network origin. Other bulk clients share that allowance; interactive work has higher queue priority and does not wait on this bulk window. Existing site-specific server rules and shared `Retry-After` handling remain in force. This interval is an application policy, not a claim about Rule34's current server limit.
- Recovery preserves rate-limit and cancellation outcomes. On HTTP 429 or a shared cooldown, the batch records one failed candidate and skips remaining candidates from that source for this run, preserving them for a later explicit attempt. It continues hydrating unrelated sites. The page names the rate-limited sites and explains that their remaining bookmarks were skipped.
- Bulk maintenance reuses existing protection cookies but does not launch interactive verification or replay a protection challenge; ordinary viewer browsing retains its existing handling.
- Regression evidence: the two cooldown tests, missing bulk-pacing test, and bulk verification test were first observed failing on the previous implementation. Final verification passed 150 tests across all `test/core/http/client/` tests, hydration, maintenance UI, bookmark provider, and bookmark viewer tests. Added coverage proves other sites continue, request context reaches the real maintenance notifier, and the cooldown result is readable at 320 px width with 2x text. Focused analysis of all 11 affected Dart files reported no issues; formatting and diff whitespace checks passed.
- No live authenticated Rule34 hydration, feed access, APK installation, or emulator checks were performed. A separate access/parsing problem affecting every Rule34 bookmark is not established or ruled out by these tests. The existing Rule34 single-post recovery endpoint was retained.

## Follow-up: independent site processing (2026-10-07)

At the user's request, hydration now processes up to three distinct source sites concurrently. Each site's bookmarks remain sequential and use the exact profile selected by `PostOriginResolver`; multiple profiles for the same source site share one queue. This prevents a site waiting on its request allowance from blocking other active sites while retaining the 1.25-second bulk window at each actual transport origin. The limit is shared by site, not multiplied by the number of profiles.

Only the three bounded workers are joined with `Future.wait`; there is no future per bookmark. Counts and site deferral remain shared, successful snapshots are still persisted immediately, and the library is still refreshed once after all workers stop. Cancellation stops new work across queues and keeps each already dispatched successful upgrade.

Verification: the cross-site blocking and mixed-library concurrency tests were first observed failing with the sequential implementation. All 51 tests in hydration, maintenance UI, bookmark viewer, and request coordinator files then passed. Additional coverage verifies at most three requests in flight, cancellation persistence across active sites, and exact profile selection with sequential requests for two profiles on one site. Focused analysis of the two changed Dart files reported no issues; formatting and `git diff --check` passed. No live site or device validation was performed.

## Follow-up: automatic continuation after rate limits (2026-10-07)

The user explicitly rejected requiring manual restarts after rate limiting. This supersedes the earlier behavior that skipped the rest of a rate-limited site for the current run.

- Rate-limited requests retain the same pending bookmark and do not increase processed, skipped, or failed counts. Recovery preserves the shared coordinator's retry deadline, including server Retry-After handling. The site resumes automatically after that deadline, retrying until a terminal outcome or user cancellation. Raw 429 responses without a deadline use escalating 30/120/600/1800-second fallback waits; expired deadlines still wait at least one second to avoid a retry loop.
- The bounded three-worker scheduler now selects ready site queues after each bookmark. Cooling queues release their worker slots, so additional sites can progress even when three other sites are paused. Profiles for the same source still share one queue, and existing per-origin bulk pacing remains unchanged.
- The localized maintenance page explains that the affected sites are waiting and will resume automatically. Cancelling interrupts idle cooldown timers immediately, stops new work, and retains completed in-flight snapshot writes. Cancelled runs do not advertise automatic continuation. App restarts still retain completed work but do not restart the maintenance operation automatically.
- Verification: all 90 tests passed across hydration, maintenance UI, bookmark viewer, bookmark provider and API coordinator files. Coverage includes server deadlines, raw 429 fallback, repeated rate limits within one run, slow responses, expired deadlines, cancellation during a 30-minute cooldown, and a fourth site progressing while three sites cool down. Existing identity/membership, parallelism and single-reload checks still pass. Changed Dart files were formatted; focused analysis of all four changed Dart files reported no issues; translations regenerated with `./gen.sh i18n`; `git diff --check` passed. No live authenticated Rule34 or device checks were performed.

## Follow-up: Rule34 recovery through the API (2026-10-07)

At the user's request, Rule34 single-post recovery now uses the documented `https://api.rule34.xxx/index.php?page=dapi&s=post&q=index&json=1&id=...` endpoint instead of parsing the HTML post page. The existing configured client supplies the selected profile's `user_id` and `api_key`; both viewer recovery and maintenance hydration use this shared lookup. Other websites retain their existing recovery implementations.

The parser accepts decoded JSON lists and JSON text, reuses the native API DTO mapping, and checks that the returned post ID matches the requested bookmark and includes a file URL. Only an empty API list means a removed post. Error objects, HTML challenges, malformed records, and unexpected IDs fail recovery without incorrectly declaring removal or writing another post's metadata. Existing per-origin pacing and automatic cooldown continuation remain in effect. Rule34's API documentation supports a single `id` lookup and listing up to 1000 results, but does not document an arbitrary ID-list lookup; this change retains one request per bookmark.

Verification: all 50 focused tests passed across Rule34 API recovery, website capability lookup, and bookmark hydration. New coverage checks the actual configured endpoint and credential parameters, preserved metadata, native codec compatibility, removed posts, JSON text, and invalid payloads. Existing Realbooru recovery and hydration retry/cancellation/identity checks pass. Changed Dart files were formatted, generated configuration/parser outputs refreshed with `./gen.sh booru`, focused analysis reported no issues, and `git diff --check` passed. No live authenticated Rule34 requests or device checks were performed; resolving the user's actual live failures remains unverified. API documentation: https://api.rule34.xxx/.

## Follow-up: per-post status log (2026-10-07)

The maintenance page now shows a live post log below the status controls, newest entries first, with a Copy log button. Each entry identifies the source domain and post ID (or local bookmark ID when the post ID is missing), UTC timestamp, and outcome. Skip reasons distinguish missing/ambiguous profiles, missing post IDs, unavailable posts, and unavailable native metadata. Request failures include the HTTP status when available; save failures are separate. Rate limits log a waiting entry with the automatic retry deadline and retain the existing non-terminal count behavior.

Only the latest 100 entries are retained in memory and copied. Progress snapshots are immutable; the log remains available after completion/cancellation and when returning to the page, and a new run clears it. The log uses structured fields rather than raw request/error text, so credential-bearing exception messages are not copied. It is not persisted across app restarts.

Verification: 32 hydration and maintenance widget tests passed on the final implementation, including 100-entry retention/eviction, immutable snapshots, skip reasons, HTTP failures, save failures, retry deadlines, cancellation and restart, live updates, missing-ID identity, and clipboard contents. UI checks run at 320 px width with 2x text, including a long domain and the Copy log action; no keyboard interaction applies. Twelve shared bookmark viewer tests also passed. Changed Dart files were formatted and translations regenerated with `./gen.sh i18n`; focused analysis of seven affected Dart files reported no issues; `git diff --check` passed. No emulator or live site checks were performed.

## Follow-up: detailed failures, automatic failed-post passes, slower Rule34 pacing (2026-10-07)

At the user's request, recovery now distinguishes connection failures, timeouts, TLS/certificate errors, invalid responses, access-denied responses, and other HTTP failures. The screen and copied log include a bounded first-line diagnostic for parser/metadata and local save failures; profile credentials and authenticated URLs are redacted, and raw HTTP bodies/transport error text are excluded. Rule34's parser reports HTML/non-JSON responses, API error objects, mismatched IDs, and missing file URLs separately, retaining the existing removed-post semantics.

After a complete pass, hydration automatically retries only the request/write failures, until none remain or the user cancels. Successful updates and terminal skips are not fetched again. Retry passes wait 30/120/600/1800 seconds, capped at 30 minutes between later passes; permanent errors continue with that backoff until cancelled. The failed count tracks remaining posts instead of attempts and decreases as retries succeed or become terminal skips. The status page shows the next retry time/current pass and keeps cancellation available. Existing HTTP 429 deadlines and per-site continuation still apply during retries. No full-library reload occurs per pass; the existing final reload remains once per operation.

Rule34 maintenance requests now use one start every two seconds at both `rule34.xxx` and the actual `api.rule34.xxx` transport origin. This is application pacing, not a change to server cooldowns. Other origins retain their existing pacing and interactive requests remain eligible.

Verification across targeted runs covered 83 passing tests in hydration, maintenance widgets, API coordinator, Rule34 API recovery, and bookmark viewer files. The final hydration file passed all 33 tests, including failure-only passes across sites, stable counts, transient write recovery, repository diagnostic propagation, credential redaction, escalating/capped delays, rate limits during retries, and immediate cancellation of a real retry timer. Coordinator checks prove the two-second Rule34 spacing, other-origin pacing, and interactive eligibility. Widget checks cover detailed copied diagnostics, retry waits/passes, and cancellation at 320 px width with 2x text. All changed Dart files were formatted; focused analysis of 11 affected Dart files reported no issues; translations regenerated with `./gen.sh i18n`; `git diff --check` passed. No live authenticated Rule34 or device checks were performed, so the cause of the user's live failures remains unverified.
