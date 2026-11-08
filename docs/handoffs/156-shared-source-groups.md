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

## Remaining exit gates

Run the complete local suite on the committed candidate without runtime/test
edits during the pass, then inspect final evidence and the complete issue delta. Exercise the required
Android/native service paths under an exclusive lease, preserve/restore the
original APK, data and settings, record unavailable services honestly, and obtain
independent Sol High approval. Any findings require fixes, retesting and
re-review before #140. No PR, push, merge or issue closure is authorized.
