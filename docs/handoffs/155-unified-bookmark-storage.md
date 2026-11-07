# Unified Bookmark storage and migration (#155)

Status: locally complete after required verification and independent Astra High approval. Paused by the user before #142; no integration or publication is authorized.

Branch/worktree: `maintenance/155-unified-bookmark-storage` / `.worktrees/155-unified-bookmark-storage`. Base: `f3bb2d30b92116dff44dac8fc6aceabbc67a3d14`, stacking the independently reviewed [#132 prerequisite](132-preserve-favorites-sync-group-contents.md) and [#154 foundation](154-content-group-contracts.md). Approved planning reference: `fdb68f657284e1f76701c83683aa0228484d09c8` in `.worktrees/content-architecture-reference`, stage 02 and its approved contract/review protocol.

Runtime/test candidate: `6b390c611b5dc4b4dcf8356172635fd698356678`, tree `684d0d46d68c4fbf276427794e5e06a42f872228`. The eventual handoff-only commit does not change this checked runtime.

## Resulting behavior

`Bookmark` carries only its local integer ID. `PostBookmark` retains existing Post snapshots and media accessors. Native Group/Related records own Summary, optional already loaded Details and separate source-tag/member-union indexes. Related alone has an optional order preference. Thin Pool/Related projections derive memberships and independent dates exclusively from `BookmarkGroup`; static covers no longer fabricate Posts. General saved-record selection, frozen actions, deletion, copying, folders and Undo support all kinds.

One shared uint32 allocator syncs its monotonic reservation before exposing IDs. Payloads, kind/content indexes, tombstones and organization share a durable journal/coordinator. Completed asynchronous lock scopes cannot authorize later callbacks. Confirmed small mutations update immutable indexes without decoding the complete library; ambiguous writes invalidate cached state. Public facade deletion journals membership detachment with payload deletion.

Startup preflights legacy data, persists its UUID-to-integer map/recovery plan, stages a separate organization generation, validates source memberships/dates and durably activates it before publishing repositories. Migration preserves existing Post snapshots and legacy organization source files. Readable unaddressable Posts and unknown legacy Collection engine IDs remain saved without invented dedup keys, aliases or transport schemes. Unsupported new Group structures fail preflight.

v10 has one tagged Bookmark array with integer membership references. File IDs never select local slots or raise the allocator. Import validates all records and organization before allocation, then commits through the shared journal. Preview and apply share preparation and record semantics; known compatible identities follow the selected merge/replace policy, while opaque records remain independent. Default placement, nested folders, historical membership dates, loaded Details and Related order survive transfer. External transfer omits local Post source-page URLs and invalid profile hints; internal recovery retains local data. The profile prerequisite remains intentionally for #142.

Saving Pool/Related references performs no detail/member/media or blacklist preparation. First Related save captures the visible direction atomically. Existing Pool descriptions/source dates flow through transient DTO fields into native Details; repeated membership saves keep the saved observation. Partial observations retain unknown fields; authoritative deletion remains explicit. Danbooru keeps DText. Szurubooru raw Markdown is preserved verbatim as literal plainText within the approved shared format contract; native Markdown presentation is unchanged.

## Significant fixes and independent review

Behavioral RED/GREEN and fault-injected tests cover expired lock reuse, standalone deletion leaving dangling memberships, Default placement reset, loaded Details loss/partial erasure, and stale removal Undo after a fresh Group save. Genuine preparation failures and obsolete fixture assertions remain recorded as failures, not passes. The UI harness now exercises production unified mutations with in-memory Hive; its explicit no-op durability and generation-existence substitution are separate from real-filesystem and native recovery checks.

First final review: actual `gpt-6-astra`, High effort, independent of implementation/canonical tests/fixes, reviewed the whole base..`4650ad6f0942efc30c5fa6a8e66fbcfb6fc582da` delta and live #155. Verdict: **CHANGES REQUIRED**, one P1 and no second confirmed defect. Profile-hint remapping inferred a numeric upstream ID from deliberately unaddressable legacy data, allowing import deduplication to collapse the independent record. Raw report: `astra-high-final-review.md`.

Fix `6b390c611b5dc4b4dcf8356172635fd698356678` copies the saved nullable upstream ID, snapshot, decoded view, dates and local URL explicitly while changing only the hint. Seven canonical pre-fix regressions reproduce promotion/collapse. Nine new cases cover retained custom-payload versions, flat data, real v1 Hive migration, v10 decoding, hint mapping, actual preview, Merge/Replace, allocation, metadata/dates and cold reopen. The affected backup/Post/preservation command passes 668 tests.

Independent final re-review: **APPROVE**, actual `gpt-6-astra` at **High** effort, exact candidate `6b390c611b5dc4b4dcf8356172635fd698356678`. The reviewer authored no canonical implementation, tests or fixes. It inspected all three remediation paths, retained whole-delta audit coverage, and independently reran its unchanged identity/import probe with the two focused canonical files: 20 tests passed. It verified the new exact-candidate full-suite/native provenance and clean state. No additional confirmed correctness or data-safety finding remained. Raw report: `astra-high-final-rereview.md`; focused log: `reviewer-probes/identity-rereview-6b390.log`. Approval does not grant publication or integration.

## Verification

Pinned FVM Flutter 3.47.2 / Dart 3.13.2; six detected physical-core test workers. No dependency/toolchain upgrade or generated runtime output change.

- Formatting: all 172 changed Dart files, zero changes.
- Full-delta analysis: zero errors, zero warnings, 429 informational findings, exit 0 with no-fatal-infos. Informational findings remain disclosed; this is not a no-issues claim.
- Affected backup/profile-import, Post and storage-preservation tests: 668 passed.
- `./scripts/run_regression_tests.sh`: exit 0 on the unchanged clean candidate, 2026-11-07 09:24:21-09:40:51 UTC. Passed 6,372 application tests, 1,661 package/CLI tests, both shell policy/release suites and 76 Python tooling tests. Two existing go_router skips remain disclosed: routing-config shell-route handling and obsolete StatefulShellRoute branch cleanup. No complete test root was omitted.

Durable evidence root: `.worktrees/_artifacts/content-architecture/155/`. Actual commands/results are in `verification-results-6b390.json`, `identity-remediation-{format,analysis,affected}.log`, `full-regression-6b390-{start,result}.json` and `full-regression-6b390.log`. Every package test root ran: booru_clients 238, boorusama_cli 254, cache_manager 59, coreutils 191, dtext 59, extended_image 47, filename_generator 31, flutter_sqlite3_migration 45, foundation 65, go_router 436, i18n_cli 32, kurumi 188 and retriable 16. Superseded successful suites at e796/4650 do not prove the corrected final runtime. Initial fixture compile/envelope errors and the pre-fix behavioral RED logs are retained separately.

## Native evidence and limits

The leased Android 17/API 37 x86_64 campaign uses a disposable isolated app-documents database and production factory/migration/codec/import paths. Verified v9 recovery backup plus original Hive files are archived before upgrade; flat media not representable in v9 remains covered by the raw archive. Legacy then exact-current APK installation, migration, fresh-completion cold restart, v9 Merge, v10 full Replace and final fresh-completion cold restart all pass. Snapshots, independent dates, folders, Default position, Related preference, revision and allocator fingerprints are checked. A non-persisting native hint/codec assertion checks both Posts, including the explicit null upstream ID, at every boot.

Candidate APK SHA-256: `2092625ce6303aa026f6e359e13c92ff5d45f130ef89df479544c4c029a0daad`; build and installed hash match exact runtime `6b390c611b5dc4b4dcf8356172635fd698356678`. Fixture source SHA-256: `7cf3c993e7cfe1112c2c751ef88f723b6eb975b7ad928bec6036075a605e03f0`. Closed final database archive: `2c8971559a44de8f63686c8afcbfb376ac991620f1db9fde8e18bbc68d5ce5cb`.

Raw evidence is under `native/final-identity/`, aggregate `native-evidence-6b390.json`. An earlier campaign read a previous boot output before readiness; the final campaign parks the old QA output and waits on a fresh completion file without fixed sleeps. No domain data is reset to satisfy a comparison. The original APK and exact permission grants/flags are restored, rechecked after installer completion, the app stopped and all leases released. Earlier QA datasets remain parked and archived.

This proves synthetic native storage/codec/helper behavior, not normal application bootstrap, live-service access or responsiveness. Actual profile mapping through preview/Merge/Replace and cold persistence is additionally tested in host real-Hive tests; UI behavior is checked by widget/application tests. No device timing or live API result is claimed.

## Delivery and pause

Local only. No PR, push, develop integration, issue closure or release was performed. #155 stays open pending acceptance and authorized publication. The required checks and independent re-review have passed. This handoff completes #155 locally; **pause before #142**, as explicitly requested. Preserve the isolated branch/worktree and unrelated work. Resuming the rollout requires the user.
