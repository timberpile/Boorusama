# #144 — MiteMite code-review remediation handoff (2026-11-17)

## Assignment and boundaries

Continue **`feature/144-folder-based-collection-sync`** in `timberpile/Boorusama` (issue **#144**). This handoff is based on a **static remote review** of branch HEAD **`2d98598ece12ae5eedacb4e58d24e45ef50a437a`**, compared against `develop` at `fa40038f8a073a1fa74482c9a75b139a5e0a06c4`. Revalidate these refs and actual code before changing anything; another agent may have pushed commits.

**Goal:** Reproduce, fix, and regress all four functional review findings below, then correct the obsolete documentation. These are specific review hypotheses with code-path evidence, **not** already executed reproducer tests. Write failing reproducer tests first. If any finding cannot be reproduced, investigate fully and report the contradictory evidence instead of applying a speculative change.

Follow the current `AGENTS.md`, `docs/development_workflow.md`, `docs/engineering_guidelines.md`, and the repo's `.agents/skills/verify-change/SKILL.md`. Reuse the existing issue branch and its isolated worktree; preserve all unrelated work. All code, tests, commits and documentation must be **in English**. Use `fvm` for Flutter/Dart.

**Do not** merge/rebase into `develop`, open a PR, close #144, delete the branch, or operate an emulator/protected device without fresh explicit owner authorization. No new issue is necessary; all findings belong to #144. Commit and push scoped fixes to the existing branch.

## F1 — P1: historical withdrawal links can invalidate an otherwise valid catalog

**Inspect:** `lib/core/backups/mitemite/catalog.dart` (`SyncCatalog` hierarchy validation); `lib/core/backups/mitemite/service.dart` (`_publish`, historical entries); `receive_units.dart`.

**Scenario:**
1. Publish Bookmark Group A containing B; receiver subscribes to A.
2. Move B to Home; B leaves A's effective publication scope and is advertised as withdrawn with its historical `parent=A`.
3. Move still-published A underneath B in the local hierarchy (which is valid).
4. The new catalog has active A with `parent=B` and withdrawn B with `parent=A`. The validator currently includes both states, reports a cycle, and blocks outgoing publication. Unrelated changes, including Following changes, can remain blocked because the catalog is global.

**Required fix:** Validate *live hierarchy edges* using only `SyncPublicationState.active` entries. Maintain historical tombstones, IDs, revisions, anti-replay high-water marks and signed withdrawal authority unchanged. Do not strip tombstones or reset counters. Confirm active sources may legitimately point to unpublished/withdrawn parents, which are not implied subscriptions. Reject genuine cycles among active entries.

**Tests:** First demonstrate failure through the real publisher/catalog path; then assert successful signed publication, receipt of A, removal of uncovered B, continued unrelated publication and preservation of replay/retirement barriers. Add equivalent Following-folder hierarchy coverage and explicit active-cycle rejection.

## F2 — P2: two distinct received Following roots collide if they share a name

**Inspect:** `lib/core/backups/mitemite/following_mirror_engine.dart` (root projection, `TopicFolder.nameScope`), `lib/core/groups/folder_tree.dart` (`FolderTree.validate`), `lib/core/search/following_topics/src/data/hive/following_mirror_storage.dart` (owner/scope validation and recovery), `lib/core/search/following_topics/src/types/topic_organization.dart` (scope reconstruction).

**Scenario:** One publisher has `Artist A / Favorites` and `Artist B / Favorites`, and directly publishes both child folders (the parents are not subscribed). On the receiver each child projects as `parentId=null`; both carry the same publisher-only `nameScope`. `FolderTree.validate` treats their identical case-insensitive names as duplicate siblings, rejecting the second otherwise valid subscription.

**Required fix:** Preserve publisher-owned canonical names and source IDs. Differentiate *source sibling uniqueness* from the receiver's virtual-root presentation: received name validation must use the original publisher/source-parent namespace (or an equivalent stable collision-free source-sibling identity), rather than collapsing every projected root of one publisher into a single name namespace. Apply consistently when receiving, unsubscribing an ancestor, reparenting, persisting/reloading and recovering the journal. Update the existing storage invariant and decoder maps; do not change local-folder uniqueness or append synthetic suffixes to source names. Ensure distinct publishers remain isolated.

**Tests:** Receive both same-named direct child roots; restart and read; rename/reparent either source; unsubscribe one; remove a subscribed ancestor while a separately subscribed descendant survives. Validate unchanged canonical names, local UUID mappings, order, and owner authority.

## F3 — P2: a local copy of a profile-less public Following topic loses its source

**Inspect:** `following_mirror_engine.dart` (`createLocalCopy`), `lib/core/search/following_topics/src/providers/following_topic_config_provider.dart`, the Following topic model/repository codecs, anonymous-access policy and existing "Create Local Copy" actions.

**Scenario:** Receiver has zero saved profiles and subscribes to a publicly readable received Topic. Its mirror owner holds the credential-free source reference, allowing anonymous access. Copying the Topic makes a normal local item with the unresolved placeholder `profileId`, without that mirror-owner reference. The local resolver (which sees `owner == null`) looks only for a saved profile, so the copy cannot load its source.

**Required fix:** Make local copies *usable and independent*, including after unsubscribe/Forget. Preferred solution: keep a durable, **local-only, credential-free** source reference/appropriate binding for copied Topics and resolve eligible public sites via the existing explicit, revocable anonymous-source policy. Do not copy credentials, fabricate accounts, keep mirror ownership, bypass policy/site/CDN/blacklist checks, or silently grant anonymous access to an unsupported site. Check persistence, import/export/backup compatibility and refresh/preview authorization. For sources that cannot be resolved anonymously or via an explicit compatible local profile, require user-visible binding or fail the copy **before committing anything**; never produce a silently broken copy. Apply to nested folder/Feed copies atomically.

**Tests:** With zero profiles, receive a policy-allowed public Topic, verify it opens, create a local copy, unsubscribe/Forget the publisher, restart, and verify the copy still resolves through current public policy. Revoke policy mid-request and ensure its access is revoked. Cover unsupported/private site, ambiguous multiple local profiles, mixed resolvable/unresolvable nested copies, and failed-copy rollback/no partial tree.

## F4 — P2: case-sensitive local-copy naming conflicts with case-insensitive folder rules

**Inspect:** `following_mirror_engine.dart` (`localFolderName` inside `createLocalCopy`); `FolderTree.validate` and `FolderTree.uniqueName`.

**Scenario:** Existing writable root is named `favorites`; a received root is `Favorites`. Creating a writable copy currently sees no case-sensitive match, chooses `Favorites`, and fails validation, whose sibling uniqueness rule is case-insensitive.

**Required fix:** Use the same case-folding/uniqueness contract as local `FolderTree`, preferably a shared helper. Only rename the *new local copy*; never rewrite received names or affect source identities. Keep suffix generation deterministic and avoid case-insensitive suffix collisions.

**Tests:** Existing `favorites` + received `Favorites` yields a valid suffixed copy; existing `favorites` and `FAVORITES (2)` yield `Favorites (3)`. Include exact duplicates, different destinations, restart persistence, and preservation of the received source.

## F5 — P3: stale README and issue text can reintroduce superseded UX

**Inspect:** `lib/core/backups/mitemite/README.md`, issue #144, `docs/designs/2026-11-03-folder-based-collection-sync.md`, `docs/handoffs/144-mitemite-notification-routing-2026-11-16.md`, `docs/handoffs/144-open-items-2026-11-16.md`, and the most recent `144-interrupted-web-remediation-2026-11-14.md` verification sections.

**Required fix:** Update the README's outdated "three notification categories / all taps go to Bookmarks", obsolete ~20dp marker, polling interval (now one minute), and stale verification scope. State the current **five-category destination-specific** notification behavior and approved **14dp borderless tile-corner** Unseen marker. Update the *issue description/status pointers* to remove older "pending implementation" claims **only after verifying the corresponding behavior remains implemented**; reference the current canonical documents and new remediation handoff. Keep dated historical evidence tied to its actual runtime SHA; do not retrospectively claim tests. Avoid rewriting large historical handoffs merely for cosmetics.

## Execution order and quality bar

1. Refresh `origin`, inspect current issue/branch and repo guidance. Preserve local uncommitted work and do not replace an agent's concurrent commits.
2. Add minimal **red tests** reproducing F1–F4. Distinguish actual failures from mistaken review assumptions.
3. Fix F1 first (publication blocker), then F2 (identity/names), F3 (source authority/independent copies), F4 (name allocation). Small, well-separated commits are preferred. Run narrow related tests after each fix.
4. Audit knock-on boundaries: signed catalogs, withdrawal/replay checkpoints, overlap and unsubscribe, source-owned read-only guards, Following runtime/auto-update independence, snapshots/rollback/restart, local-only membership, untrusted source validation, anonymous policy revocation, alias/Feed presentation, and notification/read-state non-regression. Update F5 docs last.
5. Have an independent local reviewer inspect the final diff if available; **fix confirmed issues** and rerun relevant tests. Do not claim independent review if none occurred.
6. Before reporting merge readiness, run the **complete** `./scripts/run_regression_tests.sh` on the final immutable candidate, plus relevant `fvm flutter analyze --no-pub --no-fatal-infos`, format and `git diff --check`. Run native tests/build only if the changes require them. Follow the repository's exact complete-suite requirements; report commands, test counts, exit codes, commit and exclusions. Do not touch emulators or protected devices without fresh owner authorization.
7. Commit and push to `feature/144-folder-based-collection-sync`. Provide a concise completion report with finding-by-finding resolution, changed files, reproducer/verification evidence, remaining limitations, and pushed SHAs. Keep #144 **open** and do not merge unless separately authorized.

## Current verification context (not requalified by this review)

At reviewed HEAD `2d98598ece12`, the most recent implementation handoff reports complete host regression of **7,574 app tests + 1,711 package/CLI tests**, native JVM tests (**52**), and an Android APK build on runtime `8b840e9706d6`; its final commit is documentation-only. These are **reported prior-agent results**, not checks independently repeated for this review or future fixes. Native SAF/current instrumentation, actual shared-folder deployment and physical-device performance remain separate acceptance items.

**Success criterion:** All four behavior bugs have failing-before/passing-after evidence, no ownership/security/transaction regression is introduced, F5 is current, and the final pushed candidate has recorded full-suite verification. Do not represent a design proposal or partial test as completed implementation.

## Local remediation outcome — 2026-11-17

All four review hypotheses reproduced before their respective fixes, starting
from `a0ce0fbe3` (the reviewed runtime plus this assignment). Work remains on the existing feature branch; no develop
integration, PR, issue closure or device operations are authorized by this report.

- **F1:** Real Bookmark and Following publishers failed with `Source Group
  hierarchy cycle` after the documented move sequence. Catalog hierarchy validation
  now follows active edges only. Signed tombstones keep their historical parents,
  revisions and retirement/replay barriers. Both real publishers continue serving
  the surviving root and unrelated domain changes. Active-cycle rejection is
  tested separately for both kinds.
- **F2:** Two directly published `Favorites` folders under different source
  parents failed the second subscription. Received folder name scopes now use
  publisher plus original source parent, reconstructed from authoritative owners
  on normal reads and journal recovery. Real service coverage includes same-name
  roots, restart, rename/reparent, ordering, ancestor overlap/unsubscribe and
  stable local UUIDs. Local folder uniqueness and canonical source names are intact.
- **F3:** A zero-profile public mirror opened, but its local copy resolved to
  null after Forget/restart. Copies now carry an independent credential-free
  `FollowingTopicSource` (engine/site), stored in optional Hive field 19 and
  local runtime rollback snapshots. It carries no account, owner or access grant.
  Copy preflight rejects unsupported/private, ambiguous and revoked sources
  atomically across nested folders/Feeds. Explicit anonymous policy remains
  revocable and enforces site/CDN/blacklist constraints. Public copies participate
  in search, manual/automatic refresh, Edit and Info; Undo uses the existing
  journal to restore only its own Topic/placement/settings. Existing portable
  source-reference exports and explicit import binding remain compatible.
- **F4:** `favorites` beside received `Favorites` reproduced a duplicate-sibling
  validation error. New writable copies now use `FolderTree.uniqueName`, covering
  exact/case-insensitive collisions, suffix collisions, other destinations,
  restart and preservation of received names.
- **F5:** README and canonical source/copy requirements now document the current five-category destination
  contract, one-minute polling, 14dp borderless tile-corner marker and source-
  specific verification limits. Historical reports keep their original SHAs.

Independent static review identified additional public-copy filtering, refresh,
Edit/Info and Undo boundaries. The fixes include a targeted journaled Undo after
review found that a profile-wide restore could clear unrelated Topic history;
regressions cover both success and interrupted recovery with same-profile history
and received owners preserved. Those tests also exposed a pre-existing journal
serialization failure for typed history timestamps; private rollback format v2
preserves them while retaining v1 decoding. Independent reviewers did not execute tests or
operate devices. Exact final verification is recorded below after completion.

Durable local evidence is under `.worktrees/_artifacts/144-remediation-2026-11-17/`.
`red-tests.log` demonstrates F1, F2 and F3 before their fixes; the initial F4 fixture
had a label mismatch, corrected before `red-f4.log` demonstrated the actual
case-insensitive sibling failure. Failed compile/fixture attempts and interrupted
runs do not qualify the final candidate.

Primary changed files:

| Boundary | Files |
| --- | --- |
| Signed hierarchy and source namespaces | `mitemite/catalog.dart`, `following_mirror_engine.dart`, `following_topics/src/types/following_mirror_state.dart`, Hive organization/recovery scope maps |
| Independent source identity and access | `following_topic_source.dart`, `following_topic.dart`, `following_topic_config_provider.dart`, `following_topics_notifier.dart`, `search_refresh_coordinator.dart`, MiteMite service/provider wiring |
| Persistence, recovery and portable transfer | `following_topic_hive_adapter.dart`, `following_topic_hive_object.dart`, `following_topic_repository_hive.dart`, `following_mirror_storage.dart`, `search_runtime_snapshot.dart`, `search_backup_profile.dart`, `following_topics_source.dart`, `following_publication.dart` |
| Local copy actions and presentation | `following_topics_page.dart`, `edit_following_topic_dialog.dart`, `following_topic_info_dialog.dart`, `mitemite/actions.dart` |
| Regressions | `catalog_test.dart`, `following_service_test.dart`, `following_mirror_engine_test.dart`, `following_mirror_storage_test.dart`, `following_topics_source_test.dart`, `following_public_access_test.dart`, `local_copy_public_access_test.dart` |

### Final candidate and verification

Runtime/test candidate **`30900732c6847f08e8b288a09d015c03e8e34348`**, containing:

- `5a7e9dcb2` — active-only signed catalog hierarchy validation (F1).
- `d26ed450b` — authoritative source-parent sibling namespaces and service/recovery regressions (F2, including the real F1 publisher scenarios).
- `30900732c` — independent Following source persistence/access, atomic copy/Undo, history timestamp recovery, case-insensitive naming and consumer regressions (F3/F4).

No runtime/test inputs changed during the final complete run. Only the README,
canonical specification and this handoff differ from that checked runtime commit. The checked branch
was retained as requested; this is **branch qualification**, not qualification of
a combination with newer `origin/develop` commits.

| Check | Actual result |
| --- | --- |
| Complete `./scripts/run_regression_tests.sh` | **Exit 0**: **7,602 application tests + 1,711 package/CLI tests across all 13 package suites passed**; **2 existing Go Router skips**. Both `.github/scripts/test-pull-request-policy.sh` and `.github/scripts/test-android-release-scripts.sh` passed; `python3 -m unittest discover -s scripts/tests` passed **76 tests**. Runner detected **6 physical cores**, using ordinary concurrency 6. Opt-in `benchmark/` workloads are excluded by the normal runner. |
| Final focused regression | `fvm flutter test --no-pub --concurrency=6 test/core/search/following_topics/feed_member_rename_test.dart test/core/search/following_topics/following_public_access_test.dart test/core/search/following_topics/local_copy_public_access_test.dart test/core/backups/mitemite/following_mirror_engine_test.dart`: **46 passed, exit 0**. Includes zero-profile public-copy UI at 320dp/150% text and keyboard input, automatic refresh, held-request revocation, nested preflight rejection and actual Hive Undo/crash recovery. |
| Affected-file analysis | `fvm flutter analyze --no-pub --no-fatal-infos` on all **31 changed Dart files**: **0 errors, 0 warnings, 163 informational lints, exit 0**. Informational findings remain; this is not a lint-free result. |
| Formatting and documentation | Changed files formatted with `fvm dart format`; final `--output=none --set-exit-if-changed` checked **31 files, 0 changes, exit 0**. `git diff --check` passed; all **16 relative documentation links** in the three updated documents resolve. |
| Independent review | A separate agent reviewed the implementation and follow-up corrections, including journal timestamp encoding. Confirmed UI/refresh/Edit/Info/Undo findings were corrected; no confirmed findings remained. Review was static, with no independently executed tests. |

The earlier broad affected-directory run finished with **3,061 passed / 1 failed**:
an existing rename test removed a field by equality-property index. Appending the
new optional property preserves that existing ordering; the final focused and
complete runs above pass on the corrected candidate. Earlier compile errors,
fixture settlement failures and interrupted attempts are not acceptance evidence.
No whole-test retries, excluded failing tests or weakened timing assertions were
used to obtain the final pass. Async tests use held requests/completion signals
and controlled clocks.

Evidence: `regression-final.log`/`.exit`, `focused-final.log`/`.exit`,
`analyze-final.log`/`.exit`, `format-check.log`/`.exit`, `red-tests.log`,
`red-f4.log`, `undo-tests.log` and the other investigation logs under the durable
artifact directory above. Existing locale/VM diagnostics in host logs do not
replace the actual exit codes/assertion results.

**Limits:** No native inputs changed, so JVM/native tests and APK builds were not
rerun for this remediation. No emulator or protected-device operation was
performed. Current Android notification UI/cold-process launch, SAF/instrumentation,
on-device upgrade, real Syncthing/SMB/shared-folder deployment, two-device and
physical-device performance acceptance remain separate. Historical native/build
reports retain their original runtime SHAs. Issue #144 remains open for owner
acceptance and authorized integration; no develop merge/rebase, PR or branch
cleanup was performed.


## Approved develop integration — 2026-11-17

The owner subsequently authorized merging #144, superseding this handoff's
original no-merge/publication/closure restrictions. Integration uses one
Conventional Commit, `feat: add MiteMite collection sync (#144)`, with `Closes #144`.

- Approved feature tip: `a8757a5bf6fdcc2919a36c5a733fc83bd477abc1`.
- Current develop base: `1873e289b6c0d2919e90e39b6b311ee504d22727`.
- Squash preparation was conflict-free. The only differences between the combined
  candidate and fully tested runtime `30900732c6847f08e8b288a09d015c03e8e34348`
  are Markdown documentation/agent instructions. Every tracked non-Markdown file,
  including application/package/native sources, tests, generated-code inputs,
  dependencies, toolchain and repository tooling, is byte-identical.
- The complete local pass recorded above therefore also qualifies this combined
  candidate under the documentation-only reuse rule: 7,602 application and 1,711
  package/CLI tests, with two existing Go Router skips. Application/package suites
  were not rerun without a changed runtime. Both shell suites and all 76 Python
  tooling tests were rerun on the integration candidate and passed (exit 0).
- The source-correspondence diff and fresh tooling results are preserved under
  `.worktrees/_artifacts/144-integration-2026-11-17/`. The remediation evidence
  remains outside the task worktree and survives its cleanup.

Publication targets `origin/develop`; #144 closes only after verifying the
published commit. The completed task branch/worktree are then removed under the
approved development workflow. Other issue branches and the primary checkout
are preserved. No PR, release, new native build or device operation is included.
The native/SAF/live-service/physical-device limits above remain unchanged.
