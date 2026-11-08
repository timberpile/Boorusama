# Issue #156: shared existing-source Groups

Status: **code APPROVED by independent Sol High; stage BLOCKED by the required
real Szurubooru Android check.** All available-service Android checks and original
emulator restoration are complete. Do not start #140, publish, create a PR, merge
or close the issue before the documented stage gate is satisfied.

Branch/worktree: `maintenance/156-shared-source-groups`,
`.worktrees/156-shared-source-groups`.
Approved prerequisite base: `73087ebf863c4f97a769a2f014e5f2831f4054a6` (#143).
Final runtime/test candidate: `2074d452a4d715ebd1b15ed9d1fea8446471a4d2`.
Subsequent handoff-only commits do not change the verified runtime or tests.
The stage 05 plan and approved contract are retained on the planning branch and
in `.worktrees/content-architecture-reference/docs/plans/content-architecture/`.
The user's Sol-only reviewer instruction supersedes the older Astra table.

## Implemented runtime

Danbooru Pool/Related and Szurubooru Pool register shared Group sources in the
existing engine registry. Native routes and mixed `GroupViewerEntry` pages use
`ContentGroupPage`. Legacy Pool/Related viewer entry classes and repository
content dispatch are removed. Existing native headers, DText, timelines, sort
controls, checkpoints, selection and normal member routes remain their owners.
The #68 five-result grouping projection and counters are unchanged; #134 and
#146–148 are not implemented here.

Pool manifests retain source positions before sorting/filtering, distinct
repeated memberships, unavailable members and unknown versus empty values.
Batched real Posts populate resolved entries without per-Post requests.
Related keeps the existing canonical direct-family query and oldest/newest
semantics. Its native repository captures `PostResult.rawPostCount` before
visibility filtering and preserves that fact through origin binding. The Group
adapter uses raw progress/exact counts without changing ordinary Search's
nullable `hasMore` completeness contract.

The real Group grid deduplicates source member keys, retains repeated Post
occurrences and reconciles selection by those member keys. Existing filter-rule
changes still clear selection. Bulk actions target each engine/site/Post once.
Native Pool galleries disable colliding Post-identity Heroes and open the exact
clicked occurrence. Optional `IndexedGroupMemberSource` reads preserve numeric
page selection with one bounded native request. Explicit refresh separately
revokes old reads and invalidates envelopes/resolved Posts on every page;
ordinary page navigation preserves its snapshot.

Saved Groups use the existing generic picker and canonical library records.
Public reads require a proven locator, registered reader and the existing exact
source policy. A retired profile hint cannot borrow another same-host profile.
Refresh retains its captured actor and preserves IDs, memberships, Added dates
and Related preference. Covers use policy-checked static media descriptors and
the existing resolver/cache; no synthetic actionable Post is manufactured.
Portable Group links reuse the strict URI envelope and v1 `.bslink` format,
retain explicit profile choice and never encode local IDs/auth. Public member
routes retain anonymous access without serializing a transient account UUID.

## Commits

| Commit | Change |
| --- | --- |
| `89ca1d0f7976313839eeda86c27d2df2febe62a8` | fix: preserve unknown Szurubooru pool manifests (#156) |
| `610bd9e6b013e389f44dcd4351b673608905b463` | refactor: route existing source groups through shared contracts (#156) |
| `c0942026a56b2f43b2992695a28936109ecfa093` | fix: retain public group descriptions and refresh behavior (#156) |
| `528a5d7ddd3243a91d28e66028397d9e8e62bcd3` | fix: avoid group factory registry re-entry (#156) |
| `8dcf2ff13f1999d2f7a0e8e1502b798956144a40` | test: exercise native group repository boundaries (#156) |
| `875b6a27bad424bb4e13ec6c5a6d4a44c66786a4` | fix: retain public group member routes at root ingress (#156) |
| `881b69871d33870393cfc207b98e0ba80cd35bb7` | fix: preserve group occurrences and native pagination (#156) |
| `c0226450f492b156666e1de95e0dc15303795089` | test: verify group occurrence selection through the real grid (#156) |
| `a350dd97a6111319195ea91816f3ee712b51d395` | fix: retain parent continuation proven by exact counts (#156) |
| `2074d452a4d715ebd1b15ed9d1fea8446471a4d2` | fix: carry raw group progress without changing search completeness (#156) |

## Final automated verification

Durable evidence root: `.worktrees/_artifacts/content-architecture/156/`.
Pinned FVM Flutter 3.47.2 / Dart 3.13.2; six detected physical test workers.
No SDK/dependency upgrade or persisted-data codec/migration change was made.

- `./scripts/run_regression_tests.sh` passed on the unchanged committed `2074`
  candidate, **2026-11-08 04:32:58–04:50:12 UTC**, exit 0: **6,718 application
  tests, 1,671 package/CLI tests, two existing GoRouter skips, 39 PR-policy shell
  checks, 20 Android-release shell checks and 76 Python tests**.
  Evidence: `full-regression-raw-progress-final-{start,result,summary}.json`
  and `.log`.
- All 81 changed Dart paths are formatted, zero changes. Changed-scope analysis
  exited 0 with **0 errors, 0 warnings and 90 informational findings**; this is
  not lint-free. Evidence: `raw-progress-candidate-{format,analysis}*` and
  `remediation-final-raw-progress-dart-paths.json`.
- Focused coverage drives the actual Group/Post scope and grid for repeated
  members within/across batches, missing members, filtered selection, appends
  and unique bulk targets for both engines. Native Pool widget cases verify
  exact repeated-member tap index and absence of Heroes. The real normal
  member route opens index 2 in `[101,102,101]` and returns to the same gallery.
- All three native source types are exercised through the actual paginated
  controller for 1→3→last, previous/next and nonfirst refresh after manifest/Post
  changes. Production-registry tests retain real native repositories with
  controlled low-level HTTP, including short/empty filtered Related pages in
  oldest/newest order and unknown count metadata. They click the visible
  Load More button and reach the later Post with exactly two page requests.
- The combined final producer/Search/registry/pagination/pager/member-route
  matrix passed all 43 tests before freezing. Existing producer `hasMore`
  assertions remain unchanged, with added raw-count preservation assertions.

The native-hook message `File modified during build. Build must be rerun.`
and intermittent Dart-finalizer diagnostics remain recorded in raw logs.
The earlier #143 hooks_runner/libavif timestamp investigation applies; no source,
test, generated input or SDK upgrade occurred during this frozen pass. The actual
runner exit/result above, rather than an interrupted run, establishes completion.

## Review findings and failed candidates

Independent actual `gpt-6.1-sol` High reviewed the entire issue delta at `875b`
and confirmed three P2 findings: real-grid occurrence loss (R1), filtered Related
continuation loss (R2), and numeric page jumps/nonfirst refresh (R3). All were
resolved with regressions. Fresh independent actual Sol High reviewed the whole
85-path final delta at `2074`: **CODE APPROVE, no remaining confirmed findings**.
Reports: `sol-high-final-review.md` and `sol-high-final-rereview.md`.
The reviewer reused the exact frozen complete pass; its own FVM attempts stopped
before test execution on read-only SDK stamp/cache files and are not test passes.

Native verification also found and fixed the registration-Ref registry cycle and
anonymous root-member-route normalization. Real production-registry and root
application-route regressions cover both; fixtures no longer hide the native
repository boundary behind the generic Post repository.

Historical failures remain explicit. `c094` was interrupted after the native
cycle finding. `c022` failed an existing Search incomplete-count assertion and
was interrupted before correction. `a350` failed six existing nullable-`hasMore`
producer assertions and was also interrupted before editing. The separate raw
count fact preserves that contract; the `2074` full pass supersedes those runs.
Earlier `8dc` and `875b` complete passes are historical evidence, not substituted
for the final candidate.

## Final Android evidence

Final normal `lib/main.dart`, dev/debug APK at `2074` was built, retained and
installed with matching SHA-256:
`df5516665eb8d3598f4ca1d1af5005fae215c73646df90ff5abe7239c1efd3a1`.
Provenance and all final native evidence are in `native-remediation/` beneath the
evidence root. `2074-native-acceptance-summary.json` validates 11 passing flows.
All device UI control used Maestro MCP under the exact `emulator-5554` lease.

At 320dp width and 2x system text scale, real Danbooru-compatible AIBooru checks
passed:

- True cold Group URI/profile choice; Pool 80 title/DText, normal member/Back,
  selection/Back clearing, deep loading to 130 members and deep member return.
- Actual Related family 184723, Oldest→Newest, member opening and Back retaining
  Newest. Decoded media is evidenced by final private-member and Related-member
  screenshots; early gallery/deep captures can contain placeholders. No blanket
  decoded-grid, decoder-throughput or device-responsiveness claim is made.
- Two real occurrences of Series 146 in one mixed sequence. Each has two raw
  members, with five nongroup Posts between them: first Latest→last Ordered,
  both outer bounds, return to first still Latest, selection suppressing outer
  swipes, and member/Back retaining the first occurrence. Landscape→portrait
  retains Latest and the 17-member count. The preliminary one-member-per-occurrence
  query correctly stayed ordinary Posts; read-only VM inspection confirmed
  metadata/source identities, and its owned forward was removed. No runtime
  change was needed to correct that QA setup.
- B was manually selected, only disposable QA profile A was deleted through
  normal Settings/Profiles, and the saved Default/Pool 80 record remained.
  It reopened publicly without Download, including member/Back, while B remained
  on the same host. A fresh URI then bound to the sole B profile and showed
  Download as the control. A/B had no login/API credentials; this proves app
  binding/access behavior, not signed-account remote write authorization.

One initial cold chooser race and one exact-text selector for a combined
profile-name/site label failed as setup diagnostics; corrected passing flows
and their inspected hierarchies are retained. Earlier `875b` native evidence
also includes generic saving and a one-document Android share sheet; no recipient
was chosen. These older captures are not relabeled as final `2074` device checks.

## Original device restoration

The original APK, all **nine** root data directories and **212** archive entries
are restored. Post-cleanup comparison proves zero missing, extra or changed
entries, including file modes/content hashes and link targets. Original APK hash
`6fe78d249fcf41135d6ddaa175dcd61d365b91b28c59a35f4dbab084ebf9827f`, all 31
permission entries, font/rotation/animation settings, WM size/density and stopped
state match the fresh baseline. Only journal-owned, backed-up QA parking was
removed; original and QA host archives remain. The lease is released and the
serial is available.

The initial fixed-seven-directory restore capture missed `app_webview` and
`app_textures` present in the fresh full backup. The verifier caught the 80
missing capture entries before cleanup. Guarded supplemental restoration archived
the current QA roots, restored their exact original subset, then compared all
212 entries and repeated APK/settings/permission checks after cleanup. Initial
failure reports and recovery journals remain retained.

Final proof paths under `native-remediation/`:

- `restore-verifier/after-cleanup-full-archive-result.json`: PASS, 212/212.
- `restore-verifier/restored-state-post-cleanup-result.json`: PASS.
- `controlled-state-cleanup.json` and `lease-release-result.json`: PASS/exit 0.

Future device campaigns must derive the complete root set from the fresh backup
inventory; do not reuse the earlier fixed-seven-directory assumption.

## Remaining stage gate and continuation

The required actual **Szurubooru native path is unverified**. No original
Szurubooru profile or ignored test-credential entry was available; the refreshed
availability check still reports no Szurubooru entry. Its real instance URL is
pending from the user. Host adapter/parser/registry tests do not replace this
required device check.

Once the URL and any necessary locally supplied credentials/profile are available,
finish only that native gate using the preserved verified implementation and a
fresh exclusive lease/full-root backup. Preserve and restore the device again,
record actual evidence, and obtain independent Sol High stage-gate confirmation.
Reuse the unchanged `2074` complete pass across documentation/device-only updates;
new runtime/test/generated-input changes require appropriate re-verification.
Only after #156 is accepted may the rollout continue at #140, then #141/#157 and
the combined acceptance stage. No PR, push, develop merge or issue closure has
been authorized.
