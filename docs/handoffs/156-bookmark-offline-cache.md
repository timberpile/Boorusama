# Offline Bookmark image-cache fix

## Integration into the resumed #156 candidate

The remote authoring report below is historical. Commit `2fbcc64e6` was inspected
and selectively ported onto paused checkpoint `5a73ae623`; no whole-commit
cherry-pick or reset was used. Both runtime behaviors and both focused tests were
retained. The local blacklist fixture was revised to its existing JSON-list
format, rendition separation was strengthened, and obsolete scoped-key consumer
expectations were adapted while retaining actor and cancellation assertions.
The paused allocator/namespace/snapshot additions were removed under the user's
explicit URL-cache decision; no Bookmark, profile or media-cache migration was
added. See [the active remediation handoff](156-bookmark-review-remediation.md)
for current executed checks and remaining Android/final-review gates.

## Branch and scope

- Branch: `bug/156-bookmark-offline-cache`.
- Exact base: `363ab86729493e438d12bb4d07c3f5e0afac80a4` from
  `maintenance/156-shared-source-groups`.
- Related issues: #143 and #156. Neither issue is closed by this patch.
- The user explicitly requested a separate branch so the local agent can fix
  the other Bookmark review findings independently. Do not reset the #156
  worktree or overwrite its concurrent changes. Apply this branch's commit to
  the ongoing candidate, resolving only its two runtime-file changes.

The user's latest decision supersedes N2's proposed persistent permission-scope
architecture in `docs/designs/2026-11-08-bookmark-review-remediation.md`:
local media files use the existing URL/custom-key cache. No session, auth, or
blacklist revision belongs in an image-cache filename. This is deliberate local
cache behavior, not a new server authorization policy.

## Changes

1. `lib/core/content/content_media_access.dart`:
   `contentMediaCacheManagerProvider` returns the existing manager unchanged.
   Bookmark images, normal Browse images, and later app sessions therefore use
   the same URL/custom-key files. The provider neither owns nor disposes that
   manager. Existing cache quota, leases, atomic writes, and rendition-key rules
   remain in the underlying implementation. The old namespace helper/standalone
   scoped wrapper are not used by this provider; unrelated consumer cleanup is
   not part of this focused change.
2. `lib/boorus/danbooru/blacklist/src/providers/blacklisted_tags_notifier.dart`:
   the read-side repository uses currently available user/blacklist AsyncValue
   data instead of awaiting a successful current-user HTTP request. A stalled
   or failed website cannot hold local Bookmark image access indefinitely.
   Global and profile rules are still combined by the existing core notifier.
   Known server rules remain usable during refresh, and watches update the
   projection when server data arrives. If no server rules have been obtained,
   only the locally known rules can be applied; this is not a claim that remote
   preferences were fetched. Server-side add/remove/replace methods are unchanged.

The original failure chain was: server-user/blacklist future -> effective policy
not ready -> null ContentAccessContext -> an invisible occupied Bookmark cell.
Separately, the scoped image manager generated a new disk key every session.
Both causes must be corrected for an existing URL-cache hit to become visible.

Source binding, request cancellation, redirect/header restrictions, and stale
UI-result checks remain unchanged. No profile, Bookmark payload, membership,
backup version, remote data, or user cache file is deleted or migrated. No
Realbooru/picker/icon/performance-wide changes are included.

## Cache compatibility limit

Existing URL/custom-key entries from before #143 or from unbound Browse can be
read again if the exact rendition URL is present and the file has not been
removed by normal retention. New saved-media writes use those same stable keys.

Entries written only under the old random namespace after #143 cannot generally
be mapped back after that session was lost: the cache index stores hashed keys,
filename, size and usage, not the original URL/session namespace. This patch
preserves them but does not guess which bytes belong to a Post, scan all images,
claim a reverse-hash migration, or clear the cache. A thumbnail and a sample
with different URLs are still different files. The broader cover-candidate and
fallback work remains with the parallel remediation agent.

## Regression coverage added (not executed here)

- `test/core/content/content_media_url_cache_test.dart`: seed the actual disk
  cache using the ordinary key; read through the production content-media cache
  provider; change runtime keys/containers; dispose consumers; reopen the disk
  manager; verify bytes, custom keys and file leases survive.
- `test/core/content/danbooru_cached_bookmark_outage_test.dart`: pending and
  failing current-user reads cannot block local rules or access; replacement
  rules still work; server rules join on recovery. Two widget cases mount the
  actual saved-media access/scope/BooruImage boundary with a seeded image and an
  always-failing transport. They require decoded pixels and zero media requests.
  This is component-path coverage, not a claim of full Bookmark-page/device E2E.

## Verification and remaining local work

The authoring environment has no FVM, Flutter, or Dart. The targeted command
exited 127 (`fvm: command not found`), so neither formatting, analysis, Flutter
regressions nor Android acceptance is claimed. Edited source baselines were
verified against the fetched Git blob hashes; `git diff --check` passed. Review
was a manual source review, not an independent Sol High review.

In the full local checkout, use the pinned FVM SDK. Format the four changed Dart
files, analyze the affected scope, and run:

```bash
workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$workers" \
  test/core/content/content_media_url_cache_test.dart \
  test/core/content/danbooru_cached_bookmark_outage_test.dart
fvm flutter test --no-pub "--concurrency=$workers" \
  test/core/content test/core/bookmarks test/core/posts/details
./scripts/run_regression_tests.sh
git diff --check
```

Check the production registry's reactive server-preference updates in addition
to the repository seam used by the focused tests. Do not remove original
source-binding/transport tests merely to obtain a pass. Any old test that asserts
that *local image bytes* require a new session/account disk key represents the
superseded cache requirement; update that expectation explicitly while retaining
its distinct request/actor assertions.

For Android, preserve the existing cache and data, use the required emulator
lease/Maestro procedure, and test the normal app entry point:

1. With previously URL-cached Danbooru images, block/fail the API and image
   transport. Open the saved group: existing cached images must decode, and
   other sources must remain usable. Separate shell/policy/media timings.
2. Load an image once, force-stop the app, disable networking, reopen Bookmarks,
   and verify a real decoded image rather than a placeholder or a memory hit.
3. Switch Structure/Unified, reopen the group and open the cached image in the
   viewer. Cache hits must not depend on provider creation order.
4. Verify local filter changes and online recovery, then check credential/profile
   changes still cannot redirect a live action to another account.

Obtain the independent final Sol High review required by the existing rollout.
Run the complete suite on the final combined candidate before any authorized
integration. No PR, merge, release or issue closure is authorized here.
