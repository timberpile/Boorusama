# Migration final acceptance

Work began 2026-10-17; final verification continued 2026-10-18 (Europe/Vienna). Branch: `maintenance/upstream-v4.6.1-migration`.

Status: local repairs, independent reviews, complete automated verification and
the bounded emulator phase are complete. Runtime/test candidate: `bc55de7c2`.
The branch is ready for final user review; the unchecked acceptance cases below
remain open. See [REGRESSION_FIXES.md](REGRESSION_FIXES.md) for exact evidence and limits.
No merge, push, PR, release, or changes to `develop`/`master` are authorized.

The R01–R11 repairs continue the supplied local handoff; the broader migration
checklist remains [MANUAL_ACCEPTANCE_CHECKLIST.md](MANUAL_ACCEPTANCE_CHECKLIST.md).
An emulator check only closes the exact tested case, settings, artifact and
platform. Production-signed upgrade and platform-specific acceptance stay separate.

## Final checklist

Checked items identify the exact completed local scope. Unchecked items remain
for user acceptance; local synthetic fixtures and fresh dev installs do not
establish production upgrade or live-site behavior.

- [ ] **Upgrade and retained data:** on a disposable installation with the appropriate production-signed source/candidate, confirm package identity, signer, version-code increase, and preservation of profiles, credentials, bookmarks/folders, pinned searches, Following feeds, favorite tags, and backup settings. A fresh dev install cannot close this item.
- [x] **PIN after in-app restart (R02), fresh dev scope completed:** using known test data/PIN, enable or verify the PIN, take the profile-import path through Settings → Export and Import that requests an in-app restart, then unlock with the same PIN. Verify wrong-PIN rejection, subsequent correct unlock, change/clear behavior, and a cold process restart. The final bc55 APK passed this known-PIN cycle, including native change/clear and cold restarts; App Lock Off and the 30-second timeout were restored. Production-signed upgrade remains the first unchecked item.
- [ ] **Saved metatags (R10), remaining native Search-home case:** repeat the profile-import in-app restart with Danbooru Search as the actual post-import home; verify saved metatag read/write/delete after the replacement scope starts. Native final-APK empty-list and two-tag cold-restart persistence already passed. Use the pencil/check beside METATAGS; chip additions/deletions save immediately. Restore the original list.
- [ ] **Mutation behavior (R01):** retain the controlled actual-client request-count tests as the replay proof. On a signed-in test account, any native favorite/unfavorite smoke should reflect one acknowledged action and stable UI state. Record challenge/rate-limit cases that were not safely reproducible; do not infer wire-level replay safety from one visible heart change.
- [ ] **Short masonry thumbnails (R03):** inspect panoramic tiles with badges, score, and two quick actions at narrow widths and 200% text. Confirm no overflow, hidden action target, or neighboring-action interference. Check heart centering and burst animation in ordinary single/horizontal/vertical arrangements.
- [ ] **Static GIF quality (R04):** vary the actual Thumbnail quality options Low/Medium/High/Auto and Grid size Micro/Tiny/Small/Medium/Large, autoplay off/on, and small versus over-5-MiB/unknown originals. Confirm the static tier selection using actual resolved resources or trusted diagnostics, and preserve the original-format/size animation guard.
- [ ] **Context-menu switching (R05):** on desktop or a runtime with real secondary-pointer input, open one post menu and right-click another visible post, including retained/offstage/covered content. Confirm the visible target's actions, no tap-through, and normal dismissal. On Android, verify corresponding long-press/menu dismissal flows separately.
- [ ] **Viewer media keys and lock (R06):** complete native locked-playing Pause/Toggle, post-unlock behavior for those cases, and hidden/editable-focus event delivery. The final APK already passed unlocked Play/Pause/Toggle positive controls and locked-paused Play/Toggle; the all-key playing/paused lock matrix also passed deterministically. Use an actual loaded video and record stable timeline readings; a locked no-op needs an unlocked positive control.
- [x] **Bookmark sidecars (R07), completed native scope:** use the bookmark grid selection action → Download for distinct small test items with sidecars Off, TXT, and JSON. Compatible bookmark viewers retain their source-specific toolbar and ordinary selected-quality behavior; that is a separate path. Inspect actual output files and metadata; require no new sidecar for Off and correct source/post identity and actual Original quality for enabled bookmark sidecars, even with global Preview (shown as Thumbnail in the tested UI). This exact Off/TXT/JSON bookmark-grid case passed on b90; final bc55 rechecked sidecar finalization/retry and metadata tests. See REGRESSION_FIXES for artifact attribution.
- [ ] **Explicit source metadata (R08):** with a global preference different from the selected menu item, choose Thumbnail, Sample, Original, and supported site-specific entries. Confirm actual media and JSON quality agree, including resolver fallback when a requested variant is absent and the same cases in bulk downloads. Missing Moebooru Large/JPEG must not silently save Original under that label.
- [ ] **Bookmark mirror routing (R09), remaining native transfer/header case:** use a known permitted reachable media override and confirm bookmark downloads reach the configured destination. Final bc55 already confirmed the correct origin-specific rewritten task URL with Default active; its controlled transport failed before the server received a media GET. Inspect sanitized request/header evidence and source identity in metadata. Destination clearance and removal of inappropriate source credentials require transport/file assertions, not screenshots alone.
- [x] **Unavailable Original (R11), controlled native scope completed:** reproduce a Zerochan item/controlled fixture whose API and HTML supply no Original. Confirm visible localized failure and no Preview/Sample substitute. Final bc55 passed a fresh 640x480 Zerochan fixture with no API full and no HTML Original selector: visible “The original media file is unavailable. Retry.”, API then HTML fallback, no substitute media request and no new sidecar intent/native task. A persistent failed-task row is not required when no native task was created. Live-site variety remains part of broader migration acceptance.
- [ ] **Remaining native download and navigation acceptance:** prove background continuation and interrupted publication/crash recovery where supported; a small completed-transfer Home/resume smoke already passed. Complete constrained/tablet dialog/form actions at 200% text with the keyboard open, and video details close/reopen with retained position and playing/paused state. Actual files, small bulk transfer, metadata-only retry, Export and Import document selection, ordinary navigation, keyboard-open search, and landscape listing reachability were already exercised; use the report for exact artifact/scope attribution.
- [ ] **Restore test state after your manual checks:** restore quality, autoplay, sidecar, media-override, font/display, PIN, metatag, and profile settings changed by the test; remove only test-created data where appropriate. Release all emulator leases. Report anything intentionally retained.


Previously excluded pre-existing behavior: long-menu scrolling and narrow 200%
text wrapping of the Download network title. Windows/macOS/iOS runtime behavior
and physical-device behavior are outside an Android emulator pass.

For a GIF whose animation is rejected, use this static resource matrix with the
current **Thumbnail quality** UI labels (variant pixels, when present):

| Thumbnail quality | Micro grid | Tiny grid | Small / Medium / Large grid |
| --- | --- | --- | --- |
| Low | 180 | 180 | 360 |
| Medium / Auto | 180 | 360 | 720 |
| High | 360 | 720 | 720 |

UI Medium maps to internal `high`; UI High maps to `highest`. Final bc55's controlled
Medium-grid/Auto native case fetched 720 plus its 180 placeholder from a local
fixture with a measured over-5-MiB GIF original. A distinct changed-tier request
and the broader live matrix remain unchecked. The synthetic panorama was identified
at 2400x600 and rendered at 493x123px (Medium) / 241x60px (Tiny); full extreme-height,
score/badge/two-action/200% acceptance remains the R03 item above.


Local test cleanup is complete and all three emulator leases are released. The
fresh dev installations remain for review. Reviewer B's empty dedicated download
folder `/storage/emulated/0/Download/BoorusamaNativeQA_20261018` and persisted SAF
grant remain because the app offers no unset-folder control. A captured enqueued
WorkManager row for synthetic R09 task 1347097288 also remains; Download Manager
was empty and no visible scoped cancel control remained. Its app-private intent
was removed while stopped, but the database was not edited or app data reset.
Temporary profiles,
bookmarks, output files, private PIN/fixture keys, servers and exact reverse
mappings were removed, and display/app settings restored. The restore checkbox
above applies to any additional manual checks you perform.

A synthetic 1x1 image reached an existing debug viewer scale assertion also
present in origin/develop; the native download fixture was corrected to 640x480.
This repair does not claim to fix that separate tiny-media behavior or establish
its release-mode impact. The native screenshot request was rejected by automatic
approval review on privacy grounds; sanitized assertions and file/key evidence
were used without an alternate screenshot-capture method.
