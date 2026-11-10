# Issue #154: shared Content references and Group contracts

Issue: https://github.com/timberpile/Boorusama/issues/154
Branch: `maintenance/154-content-group-contracts`.
Issue delta base: `32ebbcc6f41347f8f40275d4912a2f7012b75549`, the reviewed #132 prerequisite plus its handoff.
Requirements: `maintenance/content-architecture-design` at `fdb68f657284e1f76701c83683aa0228484d09c8`, approved contract and stage 01.
Runtime/test candidate: `dd53259a8ee4199169596b771d7a573dd9c0e093`, tree `6a3484acd62012eb6d946533ae61c2ce539a1f15`.

## Implemented boundary

`lib/core/content/` holds validated references, immutable metadata, source-owned payload codecs, occurrence-based membership, existing-Post hydration, access-scoped sources, shared envelopes and manual Riverpod loading. The existing engine registry has one optional Group capability extension. No production Group source, new screen or storage change is enabled here. Post, PostCoreData, StoredPostSnapshot, PostResult and legacy Pool/Related viewer consumers retain their existing contracts.

ContentIdentity excludes engine; full reference equality includes engine and normalized complete locator. Existing Post stable keys and normalizers are reused. The reference codec stays in the reference library so construction remains private. `content_reference_codec.dart` reexports it; additional access/cache/provider files keep responsibilities focused. Existing portable-link helpers are public for reuse without changing parsing behavior. `fromPost` requires the original full site locator as an optional argument: PostOrigin only proves a semantic namespace and cannot reconstruct HTTP versus HTTPS. Omission returns null; legacy Posts remain renderable and retained. This is the intentional API adaptation to avoid inventing an HTTPS address.

Summary/Details keep unknown distinct from empty/zero and distinguish native tags from future indexed unions. Summary refresh retains loaded Details; explicit adapter replacement can remove metadata. A Group metadata codec writes Summary once when embedded in a future stored snapshot. Synthetic Pool, Work and Gallery-shaped fixtures prove current contracts without enabling future adapters.

Members retain separate occurrence keys/source positions and hydration by semantic identity. The controller joins concurrent next-page loads, retains prior members/cursor on next-page error, uses raw continuation after empty filtered pages, rejects stalled/repeated cursors and ignores stale generation responses. No recursive Group traversal or automatic unbounded continuation exists. Unavailable placeholders cannot carry hydrated metadata.

Access keys contain monotonic revisions, never credentials or their hashes. Current profile binding and effective blacklist/pool-cover policy are reused; only the requested supported source prepares policy/client state. A root-scoped counter prevents nested provider scopes from aliasing distinct account bindings. Trusted adapters may select a validated API endpoint while retaining the same authorization key and exact configuration. An optional source-owned bounded shared-envelope cache merges observer cancellation/admission through existing HTTP coordination.

## Verification and review

Pinned FVM: Flutter 3.47.2 / Dart 3.13.2. The physical-core detector returned 6; TEST_CONCURRENCY was unset. Fresh-worktree bootstrap resolved dependencies with FVM, CLI dependencies and missing generated output with ./gen.sh; no dependency upgrade or tracked generated-output change occurred.

Actual checks on the exact candidate:

- Format check for all 30 changed Dart files: pass, zero changes.
- `fvm flutter test --no-pub --concurrency=6 test/core/content`: 67 passed.
- `fvm flutter test --no-pub --concurrency=6 test/core/content test/core/posts/links test/core/posts/post test/core/posts/details`: 373 passed.
- `fvm flutter analyze --no-pub lib/core/content test/core/content lib/core/boorus/engine/src/booru_component.dart lib/core/boorus/engine/src/booru_engine.dart lib/core/posts/links/boorusama_post_link.dart`: no issues, exit 0. This is affected-scope analysis, not a whole-repository analyzer claim.
- `./scripts/run_regression_tests.sh`: exit 0 on 2026-11-07, 01:39:06–01:48:46 UTC; 6,234 application tests, 1,661 package/CLI tests, both shell policy/release suites and 76 Python tooling tests passed on the revised candidate.

Every package test root ran: booru_clients (238), boorusama_cli (254), cache_manager (59), coreutils (191), dtext (59), extended_image (47), filename_generator (31), flutter_sqlite3_migration (45), foundation (65), go_router (436), i18n_cli (32), kurumi (188), retriable (16). The two existing go_router skips are `routing config works with shell route` and `Obsolete branches in StatefulShellRoute are cleaned up after route configuration change`. No complete suite was omitted. Logs retain existing locale/image/hit-test/VM diagnostics; the complete runner exited 0.

Completer-controlled regressions cover order/auth/policy generations, refresh/disposal, concurrent paging, shared request ownership and nested provider scopes. Behavioral RED/GREEN logs demonstrate eager unrelated-policy work, unavailable hydration acceptance and nested-scope revision collisions before their fixes. Initial missing-feature compile errors and invalid fixture IDs are retained as failed preparation runs, not behavioral RED claims. A lower-cost read-only key inventory and narrowly scoped registration-test worker assisted; the lead inspected and corrected its fixtures, spies and integration before running combined checks.

Durable local artifacts: `.worktrees/_artifacts/content-architecture/154/` in the primary workspace, including `verification-results.json`, initial and revised exact-candidate logs, affected checks and independent-review inputs/reports. Final verification is in `revised-dd53259a8/verification-results.json` and its adjacent logs; the root initial JSON/logs belong to the superseded first-review candidate. No native, live-service or benchmark result is claimed for this inactive-contract stage. The #132 synthetic native campaign does not establish #154 device behavior.

Independent first review: **CHANGES REQUIRED**, fresh `gpt-6-astra` at High effort on `2b02907ec43cc0f4437d6ec478b9f8feaff0ecb3`. It independently inspected the entire issue delta, live issue/comments and exact-candidate evidence, and reproduced two P2 defects: old-key AsyncError retained previously loaded members/hydration/Summary/Details after revocation; unhydrated equal identities could bypass engine interpretation checks. It confirmed new keys remained isolated and revoked actions made no request. Raw report: `astra-high-final-review.md`.

Remediation commit `dd53259a8ee4199169596b771d7a573dd9c0e093` adds unconditional compatible-reference checks within batches and an incremental interpretation index across pages, committed transactionally. Nine canonical regressions cover same-page and hydration-first/none/last collisions, unchanged state/cursor/indexes after rejection, compatible occurrence retry, and loaded members plus metadata after credentials/profile removal/policy change/loading/error. Actual pre-fix run: 9 failures; after fixes: 67 content tests passed.

Source-loss publication now clears previous AsyncValue data while retaining normal same-scope page-error behavior. The pinned Riverpod 2.6 setters always call copyWithPrevious; a local AsyncError subclass overrides that operation only for source loss. This is a documented, localized `subtype_of_sealed_class` compatibility exception, with loaded-data/pending-generation regressions. No fake empty success, nullable model or dependency change was introduced. Maintain these regressions when upgrading Riverpod.

Fresh independent re-review: **APPROVE**, `gpt-6-astra` at **High** effort on `dd53259a8ee4199169596b771d7a573dd9c0e093`. This reviewer did not author implementation, canonical tests or fixes; it inspected all 30 changed files, relevant existing consumers, live issue/comments, pinned Riverpod transitions and exact revised verification logs. It independently reran all four original probes and eight canonical revocation/pending-future cases; both commands passed. No remaining confirmed correctness, data-loss or access-control blocker was found. Raw report: `astra-high-final-rereview.md`; focused logs: `astra-high-final-rereview-probes.log` and `astra-high-final-rereview-pending.log`.

The Riverpod compatibility exception is accepted only for pinned source-loss publication; reassess it during dependency upgrades. Later adapters still own endpoint/cursor and payload validation, source-native omission/deletion and safe rendering. Stage 01 is locally complete. The handoff-only commit may supply #155's base without rerunning unchanged runtime tests.

## Delivery limits

All changes remain local. No push, PR, develop merge, issue closure or release is authorized or performed. #154 remains open until approved publication. Start #155 only after the final candidate passes all required checks and independent Astra High review.
