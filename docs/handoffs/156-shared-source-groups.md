# Issue #156: shared existing-source Groups

Status: implementation and focused verification in progress. This is not stage
acceptance or authorization to publish. Required complete regression, Android
acceptance and independent final review remain pending. Do not start #140 yet.

Branch/worktree: `maintenance/156-shared-source-groups`,
`.worktrees/156-shared-source-groups`.
Reviewed prerequisite base: `73087ebf863c4f97a769a2f014e5f2831f4054a6` (#143).
The approved stage 05 plan and contract are retained on the planning branch and
in `.worktrees/content-architecture-reference/docs/plans/content-architecture/`.
The user's later reviewer instruction supersedes its Astra table: final review
must use a fresh independent actual `gpt-6.1-sol` at High effort.

## Implemented progress

Danbooru Pool/Related and Szurubooru Pool now register shared Group sources in
the existing engine registry. Native routes and mixed `GroupViewerEntry` pages
use `ContentGroupPage`; the legacy Pool/Related viewer entry classes and old
repository viewer dispatch have no remaining callers. Existing native gallery,
timeline, order, checkpoint, selection and normal member-viewer routes remain.
Member routes retain the gallery actor, including revocable public access,
without treating an anonymous read configuration as a saved profile UUID.

Pool envelopes are shared per access; native manifest positions, duplicate
membership, missing members, unknown versus empty manifests and existing sort
semantics remain distinct. Batched real Posts populate shared resolved entries.
Related uses the existing canonical direct-family query, with no inferred
chronology or new #134 grouping. The #68 search projection remains its owner.

Public saved Groups require a proven full locator, registered reader and the
existing exact-source anonymous policy. Local saving uses the existing generic
picker without creating a profile. Covers use existing static descriptors,
policy digest, thumbnail resolver and scoped media cache; a rejected descriptor
cannot fall back to its raw URL. Refresh captures and rechecks its actor.

Portable Group links use the existing strict URI envelope, validated Group
references and v1 `.bslink` format. The actual app route chooses an account
explicitly when ambiguous, pins its actor, and requires profile setup for
unapproved custom/HTTP sources. Existing native and member Post links remain.
A Group header share action sends one address document, without account hints,
local IDs, cached metadata or cover attachments.

## Actual verification so far

Durable local evidence: `.worktrees/_artifacts/content-architecture/156/`.
All runs use pinned FVM Flutter 3.47.2 / Dart 3.13.2 and six physical workers.
No SDK/dependency upgrades or user-data migration changes were introduced.

- `89ca1d0f7976313839eeda86c27d2df2febe62a8` preserves unknown Szurubooru
  manifests without shifting member positions. Focused parser matrix: 66 passed.
- `shared-groups-progress-matrix-v2`: 122 tests passed, exit 0, over actual
  production adapters/registry, pager, page-size lifetime, public picker and
  availability, Group/link-file codecs, native Pool/Related application flows,
  mixed viewer entries, public member/Back flow and Group URI route widgets.
  This is a working-tree progress check, not a frozen final-candidate pass.
- The prior progress matrix had 96 passing and 16 failing header fixture checks:
  the fixtures expected four buttons before the added Group share action.
  Updated assertions require the share button and retain all target-size,
  bounds and non-overlap checks. The rerun above passed all 16 variants.
- Three Group share widget tests passed: one decoded document/repeated taps,
  actor loss during gated filesystem preparation, filesystem failure and retry.
- Public member navigation uses a controlled anonymous scope and fake API;
  actual real Post widgets/media access keys and System Back are exercised.
  Initially one Pool metadata request plus a separate native description request
  were observed. The latter is outside public API permission: the public path
  now renders native envelope DText with the existing renderer, without widening
  the allow list. The final six public application tests passed, including visible DText and only
  the permitted JSON metadata request. Controlled
  transport does not prove live services or Android decoding.
- Group link route tests use the real application router, including decoded
  `.bslink` navigation, account ambiguity, retained actors, Add Profile full URL,
  root close and a 320dp/2x chooser. Private no-borrow assertions inspect the
  retained binding; no independent source-factory request capture is claimed.
- Five public cover widgets passed, including policy/loading/source denial and
  shared media-cache scope, with no fake Post identity. Three actual public
  Refresh application tests passed with writable Hive-backed repositories:
  IDs/memberships/dates and Related newest preference survive; held-read
  revocation cannot publish or borrow a newly added same-host account.
- All 64 changed Dart files formatted (one import-layout change); complete
  changed-scope analysis exited 0 with 0 errors, 0 warnings and 83 informational
  findings (`candidate-format*`, `candidate-analysis*`). This is not lint-free.

## Native-discovered registration cycle

Frozen `c0942026a56b2f43b2992695a28936109ecfa093` built and installed
successfully, but is not accepted. On the normal debug APK at 320dp/2x, the
real public AIBooru Pool URI rendered native title and DText, then member loading
showed `CircularDependencyError`. The controlled application fixtures had
replaced the generic Post repository and therefore missed the production graph.

The engine registration Ref lazily read `originAwarePostRepoProvider`, whose
registry dependency led back to that same registration. The fix reads the
existing engine-owned Post repository directly and wraps it with the established
`OriginAwarePostRepository.fromConfig`; no new client, repository contract or
source authorization is introduced. A production registry regression reproduced
all three failures (Danbooru Pool, Related and Szurubooru Pool) at `c094` and then
passed all three with the correction, including source/engine/profile origins.
It overrides low-level HTTP, not the Post repositories or Group factory.

The `c094` full regression was deliberately interrupted after the native finding,
with no source edits during its partial execution. It is **not a complete pass**;
`full-regression-c0942026a-interrupted.json` records this limit. The corrected
candidate requires a fresh complete suite and native APK checks. The focused
remediation passed three production-graph tests, 24 adapter/public application
tests, all 60 Pool/Related application flow tests, and both page-size tests.
Fixtures now supply the engine-native repositories at their intended fake
boundary while the new production-graph regression leaves those real providers
intact. All 65 changed Dart files are formatted; final changed-scope analysis
reported 0 errors, 0 warnings and 83 informational findings. Earlier
native screenshots/results remain failed-candidate diagnostics.

The first Android campaign is restored and released. Post-cleanup comparison
proves all 132 original archive entries unchanged; the original APK, 31 permission
entries, system/WM settings and stopped state match the baseline. Only journal-owned
QA parking and the empty original parking directory were removed. Original host
backups and a verified seven-directory QA continuation archive remain local. The actual
Szurubooru URL is pending from the user; no corresponding profile or test entry
was available. Safebooru returned HTTP 403; AIBooru public reads were available.

## Root Group member-route normalization

`8dcf2ff13f1999d2f7a0e8e1502b798956144a40` passed the complete local
suite unchanged: 6,686 application tests, 1,671 package/CLI tests, two existing
GoRouter skips, 39 PR-policy shell checks, 20 release-script checks and 76 Python
tests (2026-11-08 02:51:17–03:08:03 UTC, exit 0). This supersedes the interrupted
`c094` run but is not final acceptance after the next native finding.

The rebuilt normal `8dc` APK rendered real AIBooru Pool members and decoded
images, eliminating the registry cycle. A true cold launch directly via Group
URI also opened successfully. However, opening a member from the root portable
Group page normalized the transient anonymous configuration as a saved profile
UUID and routed to Browse recovery. Contextual Bookmark gallery pushes had
already avoided that path, so the original controlled test did not cover it.

The correction excludes anonymous configurations from saved-profile extraction
in the existing production navigation normalizer, while preserving the typed
payload and pinned member actor. The same real application-route diagnostic
failed before the fix and passed afterwards, including anonymous member media
access and System Back to the gallery. All four public viewer tests and 22
focused navigation/private/link consumer tests passed; analysis had no errors
or warnings. The revised candidate still needs complete final verification.

The earlier native gallery screenshot showed placeholders before media finished
loading; later screenshots and read-only Flutter inspection confirmed decoded
images. No loading-time or device-responsiveness claim is made. One automation
flow delivering a link immediately after a separate MAIN launch missed the
route; a proper cold VIEW launch and subsequent warm VIEW launches passed.

## Independent Sol High review and remediation

Frozen `875b6a27bad424bb4e13ec6c5a6d4a44c66786a4` passed the complete
local suite unchanged: 6,687 application tests, 1,671 package/CLI tests, two
existing GoRouter skips, 39 PR-policy shell checks, 20 release checks and 76
Python tests (2026-11-08 03:17:31–03:33:12 UTC, exit 0).

A fresh independent actual `gpt-6.1-sol` High review required changes for three
P2 findings. The code was not approved, and #140 must remain unstarted:

- R1: the real grid's default Post-ID deduplication lost repeated Pool memberships.
  The remediation projects member keys through ingestion and selection, collapses
  content bulk targets by engine/site/Post identity, disables colliding native
  Post Heroes, and opens the exact clicked member occurrence.
- R2: the native Related repository could lose continuation after banned/Flash
  filtering. Raw continuation is now captured before visibility filtering.
- R3: the cursor projection could not support existing direct numeric page jumps
  and skipped source invalidation when refreshing later Pool pages. Native sources
  now expose optional bounded indexed reads; explicit refresh separately revokes
  pending reads and invalidates envelopes/resolved Posts on any page.

Working-tree checks during remediation: 22 focused pager/production-registry/
real paginated-grid tests passed; 207 existing listing, selection and action
consumer tests passed; four native Pool widget cases passed with repeated IDs,
no Heroes and second-occurrence tap index. The final production-registry test
file passed 15 cases, including actual grid continuation after short/empty first
pages in oldest/newest order. These progress runs do not establish the revised
frozen candidate's complete pass. Final format, analysis, full suite, required
Android scenarios and independent Sol High re-review remain required.

The normal `875b` native APK proved decoded AIBooru Pool images, public member
opening and Back, selection without Download, 130-member deep loading and return,
generic saving through a credential-free QA profile and a one-document Android
share sheet. No share recipient was chosen. Proper normal profile creation
worked; a preliminary raw internal Add-Profile root-link setup asserted after
persisting the QA profile and is retained as a failed setup diagnostic. No data
reset occurred. The final cold-link check, Related, repeated outer occurrences,
source removal, rotation and actual Szurubooru path still need revised-candidate
verification. No timing/responsiveness claim is made.

## Remaining exit gates

Run the complete local suite on the committed candidate without runtime/test
edits during the pass, then inspect final evidence and the complete issue delta. Exercise the required
Android/native service paths under an exclusive lease, preserve/restore the
original APK, data and settings, record unavailable services honestly, and obtain
independent Sol High approval. Any findings require fixes, retesting and
re-review before #140. No PR, push, merge or issue closure is authorized.
