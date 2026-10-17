# Local-agent handoff: Following Topics UX consistency

Date: 2026-10-16

Repository: `timberpile/Boorusama`

Existing task branch: `feature/following-topics-ux-consistency`

Planning base: `e8bf883912ecd5a8c4154472a962aa0aabf0c09a` on `develop`

Integrated feature reviewed: `ae13f2d44c658561df8d9b3095c9d1bb028c2291`

Read the [implementation specification](2026-10-16-following-topics-ux-consistency.md)
first. It contains 22 scoped tasks (FTC-01 through FTC-22), four resolved decisions,
a source map, dependency order, and 25 acceptance scenarios. It is the authoritative
scope for this follow-up, not the old original-feature handoff.

## Mission and current state

Implement the settled consistency fixes, reproduce and correct the reported
reliability defects, and qualify the resulting branch. The core feature is
already integrated into develop; do not rebuild it or resurrect the original
`feature/0035-unified-following-topics` branch.

At handoff creation, this new branch contains planning documents only on top of
the base above. No application code, tests, translations, or generated outputs
were changed by this planning session. The prior review was source-based, not a
new device run. The integrated feature has its own recorded local verification;
do not describe it as the uncompiled draft from the earlier conversation.

The user wants familiar Pinned Searches-style UI with coherent Topic semantics,
not another redesign. The most important work is consistent target resolution,
Follow/Following behavior, trustworthy saves, and understandable state reporting.

## Authorization and workspace safety

Read current [AGENTS.md](../../AGENTS.md),
[development workflow](../development_workflow.md),
[engineering guidelines](../engineering_guidelines.md), and
[execute-plan skill](../../.agents/skills/execute-plan/SKILL.md).

Continue this existing branch in its own local worktree. Inspect registered
worktrees and local changes before creating anything. Do not modify, reset,
stash, or switch the user's primary checkout just to start the task. Do not
create another branch, overwrite concurrent commits, or reset to the planning
base. If setup conflicts with a dirty/occupied worktree, follow the current
repository isolation procedure rather than improvising destructive cleanup.

Useful read-only setup checks from the repository:

```bash
git fetch origin
git worktree list --porcelain
git show-ref --verify refs/remotes/origin/feature/following-topics-ux-consistency
git log --oneline --decorate -10 origin/feature/following-topics-ux-consistency
git diff --stat e8bf883912ecd5a8c4154472a962aa0aabf0c09a...origin/feature/following-topics-ux-consistency
```

If no matching worktree exists, attach this branch to an isolated path using
the repository's existing-branch procedure. A helper that creates a fresh branch
from develop is not a substitute for continuing the documented branch.

Local implementation and commits belong only to this task branch. The current
request authorized publishing the planning documents there; it is not blanket
permission to push later implementation, merge develop, open a PR, release,
force-push, or delete branches. Follow any subsequently supplied explicit
publication/integration authorization. Do not reopen completed work item 0035.
The FTC IDs are local checklist references, not issue numbers.

## Resolved decisions to implement

D1–D4 were resolved on 2026-10-16. Read the specification's decision register and
honor any newer explicit user instructions. These decisions no longer block work;
do not reopen them or keep their tasks marked as awaiting approval.

| Decision | Required behavior | Important boundary |
| --- | --- | --- |
| D1: manual-only Topics | Allow local following of valid searchable but untrackable queries; preserve normal opening, editing, and organization. | Show tracking unavailable. Never issue automatic or feed requests that the capability cannot support or report a fake successful check. |
| D2: selected folders | Include descendant Topics in bulk Topic actions, deduplicated by Topic ID. | Independent query copies remain separate. Show affected counts; scoped Unfollow requires confirmation and does not delete folder trees. |
| D3: profile scope | Use route-scoped Topic-owner configuration, leaving the global active profile unchanged. | The user delegated the choice to fit a future context-specific profile model; this is the selected approach. Preserve correct auth/actions and do not implement the wider profile overhaul. |
| D4: unavailable feed sources | Continue available sources automatically with a small non-blocking warning; no user action needed. | No Continue prompt or required Retry tap. Preserve cached data and failed cursors, recover through existing bounded coordination, merge recovered results safely, and keep the warning while gaps remain. |

D4 explicitly supersedes the earlier opt-in partial-history recommendation. Do
not accidentally retain strict all-source blocking or build a confirmation action
under the old wording. Optional diagnostic details are fine; the default warning
must stay small, and healthy results plus source recovery must require no tap.

Other choices remain settled: keep first-Follow confirmation/destination editing,
Following opens management, keep RSS identity and familiar cards, opt-in folder
feeds, default retention 1000, independent duplicate Topics, no automatic cache
eviction, and read-all-contained-Topics when a feed opens. Implement all 22 tasks
when execution is requested; this decision update itself changes documentation
only and does not expand publication or integration authorization.

## Implementation sequence

### 1. Establish the current baseline

Inspect actual files in the specification's source map. Start with
`topic_follow_control.dart`, search-result `_FollowTopicAction`, the tag menu,
`following_topics_notifier.dart`, and the relevant tests. The key entry-point
regression is not just different wording: Following can invoke creation without
an existing name/destination, while another entry point silently selects the
first duplicate Topic.

Build narrow reproductions against current HEAD, particularly A01–A05. Fix any
compile/environment setup issue before making large changes. Update tests whose
assertions merely codify the wrong interaction; do not discard valuable existing
migration, origin, scheduling, or delta tests.

### 2. Unify targeting and mutation behavior

Execute FTC-01–04. Resolve all matching visible Topics; carry and validate exact
originating IDs; use one controller for all entry points. Do not make widgets
independently guess which copy to manage.

Persist local definition and placement together. Keep failed editors open with
inputs intact. Decouple local success from network preview refresh, preserve
custom names, prevent repeated submission, and scope asynchronous feedback to
the operation's original query/profile. Test offline and rate-limited workflows.
Only then standardize visual states and disclosure behavior.

### 3. Fix cross-cutting correctness before polish

Execute FTC-07, FTC-11, FTC-12, and FTC-18. Particular hazards:

- Feed Info's route-specific legacy scope flag must not disagree with the
  scheduler about a modern Topic's eligibility.
- Initialization interest must follow the correct visible route owner, not a
  boolean set false by disposing some other nested feed page.
- A Topic query/profile can change without its ID changing. Invalidate captured
  history cursor definitions and reject late responses, not just updated posts.
- Clearing caches must revoke old cache writers and prevent accidental automatic
  materialization until deliberate re-opening/reloading. Preserve Topic state.

These fixes should use existing request coordination, revisions, serialization,
and rollback boundaries. Do not introduce a replacement scheduler/state framework.

### 4. Make browsing and editing consistent

Execute FTC-05, FTC-06, FTC-09, FTC-10, and FTC-17. Reuse one folder editor, full
paths, feed settings inside the current context, correct progress and empty
states, and consistent refresh/feedback components. Name actions by their effect:
Topics navigates, Feed settings configures, and Topic details diagnoses.

Inspect comparable bookmark/collection interactions and Kurumi components before
changing menus or spacing. Keep controls hidden appropriately during selection.
Do not replace a working card design because a prototype looked different.

### 5. Finish collection-scale work and compatibility

Execute FTC-14–16 and FTC-19, plus the resolved behavior in FTC-08/13/20.
Allow manual-only Topics without unsupported transport. Use a shared descendant
Topic-ID resolver for bulk actions; retain failed selections, sort folder
summaries, provide local discovery, and hide misleading empty legacy export
choices without removing their import decoder or IDs.

Use route-scoped profiles for Topic searches and all dependent actions, without
switching global browsing state. Keep the wider profile redesign out of scope.
For unavailable feed sources, continue healthy sources automatically and show a
small warning. Preserve gap/checkpoint state; use bounded existing retry/refresh
opportunities, not a new scheduler or per-row retry loop. Automatically merge
recovered data with origin-aware deduplication and a stable scroll anchor. If all
sources are unavailable, retain cached content and report that state honestly;
do not spin indefinitely or mark the sources exhausted. No Continue/Retry action
may be required to keep browsing available results or resume a recovered source.

Preserve exact independent-copy identity through backup import/export and
rollback. A label cleanup must not become a persisted schema incompatibility.
Avoid changing query normalization or verified API cursor behavior in this pass.

### 6. Measure, qualify, and report

Execute FTC-21 and FTC-22. Optimize demonstrated repeated metadata/cache work,
not speculative storage redesign. Use realistic metadata and multiple feeds;
separate host/JIT diagnostics from Android profile/release evidence.

Complete all settled acceptance cases and update the checklist honestly. If an
alleged defect does not reproduce, record the evidence and keep the desired
interaction contract without fabricating a bug.

## Verification requirements

Use the pinned SDK through `fvm`. Follow current repository instructions rather
than assuming every worktree already has generated output.

```bash
fvm flutter pub get
# Only when CLI dependencies/generation are required:
(cd packages/boorusama_cli && fvm dart pub get)
# For changed localization inputs:
./gen.sh i18n

test_workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$test_workers" test/core/search/following_topics
fvm flutter test --no-pub "--concurrency=$test_workers" test/core/backups
```

Also run affected search, artist, tag-menu, navigation, settings, cache, and
bookmark consumers identified from the diff. Format every changed Dart file
with `fvm dart format` and analyze affected scope. Regenerate other outputs only
when changed inputs or missing required output warrant it. Test the full files,
not only a passing name-filtered subset.

Use completion signals, controlled clocks, and failure injection for async work.
Do not weaken tests or add sleeps to hide races. In particular exercise cache
clearing during refresh, cancelled route owners, and material history edits.
Also test manual-only creation, overlapping descendant selections, same-site
profiles with different accounts, and automatic partial-source continuation with
no Continue/Retry tap. Cover one/several/all unavailable sources, cooldowns,
later recovery, unresolved gaps, deduplication, and scroll-anchor preservation.

Exercise the specification's A01–A25 matrix, with narrow 240/320px control
constraints where relevant, 2x text, keyboard insets, English/German, dark/light,
Back/Escape, long-press/range selection, and screen-reader semantics. Include
normal device-width walkthroughs so layout-valid widgets are also usable.

For a device/emulator pass, first read [the exclusive emulator procedure](../android_emulator.md)
and use the available approved UI tools. Never expose `.test_credentials` or
account/session data in logs, fixtures, screenshots, commits, or reports. Record
unavailable device tests as limits; do not fabricate screenshots or live-API runs.

The final runtime candidate requires the full repository gate:

```bash
./scripts/run_regression_tests.sh
git diff --check
```

It covers the application, package/CLI suites, and repository tooling. Opt-in
benchmarks are separate; run the relevant workload serially and compare repeated
same-host results. A previous pass of the integrated feature is not a pass of this
new runtime candidate. Record actual state/commit, commands, results, skips, and
limitations. Passing tests do not authorize merging or publication.

## Definition of done

- Every settled FTC task is implemented and its acceptance behavior verified, or
  explicitly reconciled with evidence that it was already correct.
- D1–D4 are implemented as resolved: manual-only Topics, descendant bulk scope,
  route-scoped profiles, and automatic partial-source continuation with a small
  warning. Genuine implementation limits are explicit, not mislabeled as open
  product decisions or silently replaced with the earlier defaults.
- Follow/Following behavior is consistent from actual search, artist, inline,
  and tag-menu entry points, including real persistence and failure outcomes.
- Folder/feed navigation, global/topic scheduling state, and cache/history
  invalidation are coherent under cancellation, configuration changes, and races.
- Existing data, disabled settings, independent Topic copies, origins, backups,
  legacy import routes, and conservative API behavior remain compatible.
- Updated documentation describes actual behavior. Keep this specification and
  handoff useful; do not create a separate tracking/verification metadata system.
- All task changes are committed on this branch; no unrelated changes are staged.
  Required checks pass on the final candidate; device/API limits are explicit.
- No merge, PR, release, push of implementation, or protected-branch modification
  occurs without the separately required authorization.

The final user report should summarize implemented contracts, the checked commit,
verification evidence, and any genuine remaining limitations. It should not be a
transcript of every operation, and should not claim completion based only on a
visual button refactor or the absence of analyzer errors.
