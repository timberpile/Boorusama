# Make pinned-search folders shared across profiles

Priority: Normal
Affected feature: Pinned-search organization and navigation

Claimed by: Codex /root, 2026-09-19
Work branch: `feature/ps-018-shared-pinned-search-folders`

## Problem and reproduction

The all-profile page groups pins by profile and shows a folder-open shortcut
above unfiled searches. The shortcut opens a second page with the same pins,
suggesting an unnamed folder. Folders themselves are profile-owned, so a user
cannot organize related searches from different profiles together.

## Expected behavior

Show one pinned-search collection with named folders above Home's search cards.
Home is the no-folder destination and has no heading on the root page. Each
search card identifies its owning profile. Named folders can contain pins from
multiple profiles while each pin still opens and refreshes through its owner.

## Acceptance criteria

- [x] Remove profile group headers and the duplicate per-profile management
  shortcut. Show named folders first with counts labeled `N items`, then Home
  cards without an Unfiled heading.
- [x] Give every pin card a small owning-profile footnote, including on folder
  pages; opening a pin preserves owner-aware navigation.
- [x] Replace the top Add Folder action with Manage folders, shown as a folder
  with a wrench, where users can create, rename, manually reorder, and delete
  shared named folders.
- [x] Offer `[Home]` and all named folders in pin and Move to folder dialogs.
  Create folder is available from Move to folder and moves the pin into the new
  folder on success. The create-folder dialog omits generic cross-profile copy.
- [x] Folder deletion warns and asks for confirmation, then removes the folder
  and all contained pinned searches. For two searches, the warning says "This
  will unpin all 2 searches in this folder. Unpinning cannot be undone."
  Cancel leaves both intact.
- [x] Preserve manual pin ordering within Home and each folder across profiles.
  Folder NEW and Refresh Folder aggregate member pins while resolving each
  refresh through its owning profile.
- [x] Profile removal clears only its own pins from shared organization;
  feed-owned sources never enter folders or Home. Backup/restore preserves
  shared membership and ordering.
- [x] If backup pins reference unmatched profiles, ask before skipping them.
  For a multi-source ZIP or server restore, cancellation stops the entire
  restore before any selected source imports.
- [x] Add focused persistence and widget coverage, and validate the key
  navigation and deletion flows on Android with Maestro.

## Design and dependencies

Follow the proposed [shared-folder design](../../superpowers/specs/2026-09-19-shared-pinned-search-folders-design.md).
The [implementation plan](../../superpowers/plans/2026-09-19-shared-pinned-search-folders.md)
records the storage, UI, backup, and verification work.
Folders have not shipped, so the current profile-folder data does not require
migration. This supersedes the folder ownership and grouping assumptions in
[PS-006](../done/PS-006-search-folders.md) and
[PS-011](../done/PS-011-all-profile-pinned-search-list-design.md).

Follow the [development workflow](../../development_workflow.md) for delivery.
Tasks 1–7 implement the approved design; Task 8 verifies integration.


## Integration verification (2026-09-19)

- Agent: Codex `/root/ps018_task8_integration`, coordinated by `/root`.
- `fvm dart format --output=none --set-exit-if-changed` over the 121 changed
  Dart files: zero changes. Three files were subsequently formatted after
  correcting five analyzer style findings.
- Final `fvm flutter analyze --no-pub`: no issues.
- Final `fvm flutter test --no-pub`: **1,138 tests passed**. The affected
  repository/notifier/all-profile widget subset also passed **42 tests** after
  style cleanup. The full suite includes shared membership/order, folder
  operations and rollback, owner-aware refresh/opening, profile deletion,
  backup round-trips, and standalone/ZIP/server preflight cancellation.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64
  --no-pub`: built and installed `app-dev-debug.apk` on `emulator-5554`.

### Android verification

Maestro MCP was unavailable in this session. The installed Maestro CLI was
used as the authorized fallback against the installed worktree APK. These
observations are separate from widget/unit test evidence.

Original development-app data was backed up before testing; all 30 files in
`app_flutter` and `shared_prefs` matched device SHA-256 checksums. Tests use a
copied data directory, two anonymous safe Danbooru profiles (QA Cats/QA Dogs),
and temporary `cat rating:g` / `dog rating:g` pins. No actual user pin was used
for destructive checks.

- Home-only: both owners' cards and footnotes visible, no Unfiled heading.
- Move picker: `[Home]` and Create folder visible; creating QA Mixed moves its
  selected pin. Moving the other owner's pin produces `2 items`.
- Folders-only root: only QA Mixed is shown when Home has no members.
- Mixed folder: both pins retain their distinct profile footnotes.
- Refresh Folder: both pins show successful Last checked/Last attempted times
  in Info after the action (17:10 emulator clock).
- Opening QA Dog search: ordinary results show the unchanged RAW query
  `dog rating:g`; the navigation drawer then identifies QA Dogs as active.

- Delete warning names QA Mixed and says "This will unpin all 2 searches in
  this folder." and "Unpinning cannot be undone." Cancel preserves the folder
  and both owner cards; confirmation removes the folder and both pins.
- Android checks passed through Maestro CLI. Profile deletion, ordering,
  rollback, and backup/preflight edge cases are covered by automated tests;
  authenticated engine combinations were not exercised on Android.

Original `app_flutter` and `shared_prefs` were restored after testing; all
30 original files match their pre-test SHA-256 checksums. Temporary emulator
data was removed, and the app is stopped. The worktree APK remains installed.
`git diff --check` passed before commit.

### Handover

Automated logs are `/tmp/ps018-analyze-final.log`, `/tmp/ps018-focused.log`, and
`/tmp/ps018-tests-final.log`; build log is `/tmp/ps018-build-final.log`. Local
Maestro flows/logs use `/tmp/ps018-*`, with screenshots under
`/home/timber/.maestro/tests/`. The detailed integration report is
`.superpowers/sdd/2026-09-19-shared-pinned-search-folders/task-8-report.md`.
This branch has not been pushed or merged; delivery follows the repository
workflow and requires explicit approval for merge.
