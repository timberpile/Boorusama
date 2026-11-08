# Offline Bookmark image-cache fix: integration result

## Current owning candidate

The separate patch `bug/156-bookmark-offline-cache` at
`2fbcc64e68fa2eb40e924d2c75d8217191c462e7` was selectively integrated into
`maintenance/156-shared-source-groups`; no whole-commit cherry-pick or reset was
used. Its exact base was `363ab86729493e438d12bb4d07c3f5e0afac80a4`.
The resumed paused checkpoint `5a73ae6233d92abef4e7f062b35114743ed5d5a6` was
preserved. Checked runtime/test candidate:
`6af367354ef8c7e09dd939543b1cbf9403f2da35`. The final reporting commit changes
documentation only. Related issues #143/#156 remain open.

**Integrated behavior passes focused and complete regression, independent Sol
High review and the exercised ordinary-main Android offline restart check.**
Full #156 acceptance still has explicit source/device/performance/Penpot gates
in the [current remediation handoff](156-bookmark-review-remediation.md).
No push, PR or develop integration was performed.

## What was integrated and reconciled

1. `contentMediaCacheManagerProvider` returns the existing underlying manager
   unchanged and does not own/dispose it. Bookmark, Browse and later sessions
   share normal URL/custom-key files. Different rendition URLs remain distinct;
   existing quota, eviction, file leases and atomic writes remain intact.
2. Danbooru's read-side repository uses currently available user/blacklist
   AsyncValues without awaiting successful current-user HTTP. Known global,
   profile and server rules are composed through the existing notifier;
   explicit replacement still replaces. Server data joins reactively when
   available. No remote preference is claimed fetched when it is unknown.
   Server mutation methods remain unchanged.
3. Imported `test/core/content/content_media_url_cache_test.dart` and
   `test/core/content/danbooru_cached_bookmark_outage_test.dart`. The author's
   environment could not run FVM (exit 127); those were unverified inputs.
   Local execution exposed an incompatible blacklist fixture. Corrected it to
   the existing JSON-list string and strengthened exact-rendition separation.
4. Removed the paused candidate's rejected `localMediaGeneration` config and
   allocator, persistent namespace and duplicate policy-snapshot layer. Bound
   video uses the stable existing `content-media` namespace. Older consumer
   tests explicitly requiring session-salted disk keys were adapted; request
   actor/cancellation/revocation assertions were retained and deferred cached
   share revocation was added.

The original chain was server-user/blacklist wait → policy unavailable → null
access configuration → invisible occupied cell. Separately, each session used
a different disk key. Correcting both allows an ordinary disk hit to become
visible. The wider remediation also preserves occupied geometry/error feedback,
healthy-source media and bounded group-cover fallback.

Current source/account binding, presentation/transport access, allowed URLs,
redirect/header restrictions, cancellation and late-publication checks remain.
Authorization is separate from persistent cache identity. No new authorization
model, cache-identity database, migration, profile, membership or backup version
was introduced; no existing media bytes or user data were cleared.

## Compatibility limit

Existing normal URL/custom-key entries are readable when the exact rendition
remains present under normal retention. A cached thumbnail cannot stand in for
a differently addressed sample. Files written only under a lost randomized
namespace cannot generally be mapped back: the index lacks original URL/session
namespace. They are preserved, not reverse-hashed, scanned or promised recovered.

## Executed checks

FVM/six physical workers were used, with final commands sequential in this
worktree. Both imported tests and their actor/policy/image consumers pass in the
complete final-candidate run. The original failed local import fixture run is
retained as `offline-focused-1.log`; it is not passing evidence.

```bash
fvm flutter test --no-pub --concurrency=6 \
  test/core/content/content_media_url_cache_test.dart \
  test/core/content/danbooru_cached_bookmark_outage_test.dart
# Both files also exercised with nearby consumers and by the complete runner.
./scripts/run_regression_tests.sh
# Clean unchanged 6af367354: exit 0, 6,743 app + 1,671 package/CLI passes,
# two go_router skips, shell policy checks and 76 Python passes.
```

Host tests seed the actual manager, recreate containers/reopen disk storage,
verify ordinary/custom keys and leases, and require decoded pixels with zero
media transport calls despite pending/failed server preferences. Recovery and
explicit local replacement retain their assertions. Full analyzer: 0 errors,
0 warnings, 3,780 informational findings, exit 1; not a zero-issue result.

Evidence is under `.worktrees/_artifacts/156-resume/` in the primary workspace.
Complete result/log: `full-regression-6af3673-result.json` and corresponding log.
Independent review: `.worktrees/_artifacts/156-independent-sol-review.md`.

## Ordinary-main Android evidence and limits

Under an exclusive exact emulator lease and all-nine-root isolation, normal UI
import/cache seeding retained all 69 original cache-file hashes and added 14
normal URL renditions. No app/cache clear, quota reset or original-file deletion
was used. Mixed Danbooru/Safebooru saved media and parent covers decoded offline.
After force-stop, PID changed 7087→2821 with airplane mode on/Wi-Fi off;
Unified persisted and four cached strips decoded. This is process/disk reuse,
not merely a memory hit. The ordinary `lib/main.dart` APK was built at `8635be8db`;
only two test files differ through checked candidate `6af367354`.

Host tests establish zero media calls. Android establishes actual offline pixels
and no recorded ImageFetcher failure; no global device zero-HTTP-attempt counter
was captured. Separate current Android local-blacklist/profile-action and Group
checkpoint/refresh checks remain open. Do not silently convert host coverage
into device evidence.

Original APK/all nine roots/settings/permissions/radio/display were restored;
independent archive comparisons match 448/448 entries, no changes. Original app
was resumed, owned external QA files/VM forward removed, and the lease released.
See `android/final-system-check.json` and the current handoff for exact provenance,
restoration hashes and remaining #156 acceptance gates. Further device work needs
a fresh lease/backup campaign; the old lease token is no longer valid.
