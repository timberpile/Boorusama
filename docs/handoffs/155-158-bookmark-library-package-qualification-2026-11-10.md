# P4 Bookmark library package qualification — 2026-11-10

Latest continuation: [manual-feedback corrections](155-158-bookmark-library-ui-feedback-2026-11-10.md) supersede the empty-group picker navigation contract and record the new exact-candidate verification. Android evidence below remains historical for runtime `973df8b9c`.

Historical qualification status: locally qualified for the owner’s manual acceptance. The owner has since approved integration; see [final integration evidence](155-158-bookmark-library-integration-2026-11-10.md).

## Candidate and package boundary

Branch: `feature/155-158-bookmark-library-package`. Current test candidate:
`bac318388b8540a57941c9f2145920f131a4dec1`; runtime source:
`973df8b9c2cd411a857805b911358fa5ebb6fb81`. The two subsequent commits change
application test selectors only. Source parent: P3 `054652c4ebc5`.

The package owns #155/#158 unified storage, staged legacy/v2-to-v3 hierarchy
conversion, integer record IDs, direct memberships and dates, retained snapshots,
v10 transfer compatibility, hierarchy/browser/picker behavior and Undo. P5
profile-independent import, P6 public readers, P7 native Group activation and
later Pixiv/Folder Sync/nhentai remain separate. P2 and P3 were independently
qualified and subsequently published as separate approved develop commits
`537cef38a` (#132) and `d2325820b` (#154). Their successful user acceptance was
reported on 2026-11-10; no repeated manual acceptance is requested.

## Repairs and independent review

- Moved the three German strings from `settings.theme.viewer.groups` to
  `bookmark.groups`, retaining all other translations and supplying German
  labels. FVM initialization and localization generation passed.
- Removed a picker branch referencing a P7 request type absent from P4. Replaced
  an accidentally copied nhentai Recent fixture with supported saved Group/Post
  records, retaining real scoped providers and Hive restart assertions. Supplied
  required empty membership sets in a hierarchy fixture.
- Restored the missing storage admission implementation required by the imported
  recovery/controller regressions. An operation pins its storage and snapshot;
  nested operations reuse admission; replacement initialization waits without
  borrowing an unfinished writer's coordinator ownership. Deferred callbacks lose
  ownership when admission ends.
- Independent Sol High review found remaining pin escapes in rename, Favorites
  consumers and import capture/apply/durability. The rename regression reproduced
  the deadlock before repair. All affected paths now use admitted repositories;
  standalone backup import captures handles inside admission. Disabling Favorites
  remains available during a storage failure, and assignment remains additive.
- Restored navigation into an empty ordinary group for child creation while
  keeping the compact 80/20 interaction. Chevrons indicate actual children.
  Top-level group titles expose the Home ancestor. Older fixture assumptions now
  target real input controls instead of ignored painted labels and check the
  approved compact layout and static preview geometry.

Independent reviewer: actual `gpt-6.1-sol`, High effort, nonauthor of canonical
implementation/tests. Final source verdict at `973df8b9c`: APPROVE SOURCE.
Lifecycle findings and remediation are in `sol-high-lifecycle-review.md` and
`sol-high-final-source-review-973df8b9c.md` under the local evidence root.
Final whole-candidate verdict at `bac318388`: APPROVE, recorded in
`sol-high-final-review-bac318388.md`. The reviewer independently reconciled
complete-suite counts, final test-only changes, archive hashes and restoration.

## Automated evidence

FVM Flutter 3.47.2; ordinary tests use six detected physical cores.
`./init.sh` passed, including translation validation/generation. Affected source
analysis at `973df8b9c` reported 0 errors, 0 warnings and 573 informational
findings. Changed Dart files were formatted with FVM.

The 226-test remediation command passed before the last pinned-consumer
follow-up. Exact `973df8b9c` affected scope then passed 1,688 tests with three
obsolete Related-picker hit-target failures, rather than a full pass. Those
selectors were corrected without changing removal/Undo/cancel/profile-removal
assertions. The later complete attempt also found one card visibility selector;
its correction preserves the drag/system-card exclusion assertions. Both final
application fixture files pass all 64 tests. Superseded/interruptible runs are not
the final complete-suite evidence. Do not infer successful analyzer/tests from the
original CI init failure, whose downstream checks were skipped.

Final complete suite: `./scripts/run_regression_tests.sh` passed at exact
`bac318388`, exit 0: 6,572 application tests, 1,677 package/CLI tests across all
13 roots, both repository shell suites and 76 Python tests. Two existing go_router
skips remain disclosed; no complete test root was skipped. Use
`complete-regression-final-bac318388.log`, its `.exit` and `final-suite-counts.json`,
not the superseded `complete-regression-4e45e1946.log` whose application phase was
interrupted after a confirmed fixture failure. No timeout/assertion was weakened.
The final two fixture files are checked separately by `final-fixture-analysis.log`: exit 0, zero errors, zero warnings and 13 informational findings.
The source analysis’s 573 informational findings are retained, not represented
as zero issues.

## Current Android evidence and restoration

Internal dev-debug build from normal `lib/main.dart`, runtime `973df8b9c`;
installed SHA-256 matches `ab6c636baa035dda6694dbaf663b7e881afcc240313d9e9c72e054b27373ae84`.
This build was used only for automated verification, not delivered as a review APK.

The exclusive `emulator-5554` campaign used isolated historical synthetic fixtures,
with original APK/data/settings backed up and parked before any fixture replacement.
Normal bootstrap migrated an active-v2 fixture with 104 records and a raw legacy
fixture with four records. Each upgrade archive is byte-identical to its separate
cold-restart archive. Current-source host verification checks raw active version 3
before repository opening and passes for both device-produced datasets, including
full StoredBookmarkCodec equality, IDs, source uncertainty, memberships/dates,
hierarchy, Related order, allocator, indexes, tombstones and no pending mutation.
The host's pinned v2 expected snapshots are fixture expectations, not a substitute
for the separate device-produced archives.

At 320dp/2x text, Maestro verified group mode persistence across restart, direct
versus subtree presentation, nested navigation, Home ancestor, child creation with
IME open, rename, empty-child deletion plus Undo and moving that child to an
ancestor. Subtree-delete recovery/Undo, source isolation, loaded Details and the
broader picker matrix remain automated host/widget evidence, not newly claimed
native scenarios. No decoded-media/live-service success, device timing, native
cancelled predictive-Back or Android file-provider backup/restore roundtrip is
claimed. An initial flow used an incorrect English mode selector and failed;
a hierarchy inspection established the actual label `Unified`, and the corrected
mode/ancestor flow passed. This was an automation selector correction.

Restoration PASS: all 1,108 original private filesystem entries match in bytes,
types and modes; original APK hash, all 31 normalized permission lines/grant flags,
settings, window size/density and stopped state match. Only task-owned controlled
containers were removed after restoration; original nine data directories remain.
The exclusive emulator lease was released. Current evidence is under
`.worktrees/_artifacts/sequential-continuation-20261110/p4/native/`.

## Manual acceptance checklist

The user builds and installs the candidate personally. Test only P4 next:

1. Switch Structure/All Bookmarks (`Unified` in English); restart and verify each
   group's mode, direct/subtree results and query behavior.
2. Navigate nested groups and ancestors; verify child navigation remains distinct
   from direct membership, including empty groups and the compact Recent section.
3. Exercise anchored/modal Bookmark pickers: toggle direct membership, enter a
   child separately, and return with Back/Escape.
4. Create, move, rename, delete and Undo; include a nested subtree and ensure other
   memberships survive.
5. Save a Post/Pool/Related item in multiple groups; retain independent dates,
   complete snapshots and already loaded Details through remove/Undo/restart.
6. Export/restore a copy using v10 and a supported legacy backup; preserve IDs,
   hierarchy and membership dates. Keep the original recovery copy safe.
7. Assign a populated Favorites Sync target; Save must not fetch and explicit
   fetching must preserve unrelated content and memberships.

No P4 integration, push, issue closure or release is authorized. P5 is a separate
provisional preparation, not part of this package's acceptance.
