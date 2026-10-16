# Implementation handoff — real merge of Boorusama upstream v4.6.1

**Created:** 2026-10-16
**Repository:** `timberpile/Boorusama`
**Task:** Implement the **entire approved 68-item migration** from upstream `khoadng/Boorusama` **tag `v4.6.1`**, including the subsequent A16 versioning-policy amendment.
**Approval:** On 2026-10-16 the user commissioned a local agent to **implement this entire migration plan**. This permits local task-branch work, not a push, merge into protected/shared branches, PR publication, release tagging, or public GitHub/Play Store release. Follow `AGENTS.md` and `docs/development_workflow.md` for those distinct actions.
**Status on handoff:** **68/68 product/technical decisions approved; local implementation is commissioned but was NOT started by the planning agent.**

## 0. Read this first: sources of truth

1. `AGENTS.md`, `docs/development_workflow.md`, `docs/engineering_guidelines.md`, `.agents/skills/execute-plan/SKILL.md` — operating rules, isolation, test requirements and integration permissions.
2. [`decisions.md`](decisions.md) — **binding authoritative record of all 68 approved decisions**, including the new A16 upstream-based version scheme. **Apply every decision**, not merely this summary.
3. [`boorusama-v4.6.1-decision-catalog.md`](boorusama-v4.6.1-decision-catalog.md) — upstream commits and their SHAs, file paths, conflicts, implementation context and tests.
4. [`boorusama-v4.6.1-decision-checklist.md`](boorusama-v4.6.1-decision-checklist.md) — all 68 IDs and short resolution summaries. Decisions marked APPROVED mean **approved in principle, not implemented**.
5. [`README.md`](README.md) — pinned comparison baseline and safeguards.
6. The **current** fork `develop` tree, after refreshing your local references. Do not assume the October 15 pinned comparison is still current.

When documents disagree, use the explicit **latest user-approved decision in `decisions.md`** and the current repository's safety rules. The source catalog's earlier hypotheses/old review prompts are not permissions to override final decisions. Report truly new, substantive conflicts instead of improvising a change to data identity, privacy, or product behavior.

## Repository language

Write all repository documentation, source comments, issue/work item text, commit messages, tests, plans and implementation reports **in English**. The sole exception is UI translation/localization resource content in its target language. All migration documents, filenames and agent reports are maintained in English. UI translation resources are the only language exception.

## 1. Fixed upstream target, and moving fork baseline

- **Upstream tag:** `khoadng/Boorusama v4.6.1`.
- **Must be present as an ancestor in the result:** `5b04bf6a164f028d41701299367d0dde74dde330` (the **peeled commit** behind the annotated upstream v4.6.1 tag).
- **Historical fork comparison baseline:** `develop d4e15586f06192f0ff4315d36a3f61ae69a752d5`.
- **Historical merge base:** `2c0ac699184854d363833ea4a3205aef0895a92b`.
- **Current remote `develop` observed during handoff:** `e8bf883912ecd5a8c4154472a962aa0aabf0c09a`. **Re-fetch; this is not a fixed execution target.**
- **Planning-only branch:** `origin/maintenance/upstream-v4.6.1-migration`. It contains the four decision documents and this handoff; its code base is old. **Do not base implementation on this branch or merge it wholesale.**
- Earlier unvalidated trial merges are **not** tested/approved code. Do not adopt their resolution as authoritative.
- The original analysis identified **150 upstream commits / 106 conflicting file paths** against the then-pinned fork; the actual conflict set can differ against newer `develop`.

Target **exactly v4.6.1**, not whatever is at moving `upstream/master` when the agent runs. Verify the fetched annotated tag resolves to the above commit. Preserve real Git merge ancestry: **do not** simulate by `-s ours`, fake merge commits, wholesale `ours` resolutions, or exclusively cherry-picking changes. Avoid accidental upstream changes beyond v4.6.1.

## 2. Local execution / permissions

Use a dedicated clean task worktree based on the latest *locally permitted* `develop`, leaving the user's primary checkout untouched. Inspect any existing matching worktree first; reuse it if already created. Recommended helper:

~~~bash
python3 scripts/agent_worktree.py status upstream-v4.6.1
python3 scripts/agent_worktree.py create upstream-v4.6.1
~~~

Confirm actual paths and branch names printed by the helper; do not assume a directory path. Fetch remote refs and pinned tag, where remote access is available:

~~~bash
git fetch origin develop maintenance/upstream-v4.6.1-migration
git fetch upstream refs/tags/v4.6.1
git rev-parse 'FETCH_HEAD^{commit}'
# The peeled result MUST equal:
# 5b04bf6a164f028d41701299367d0dde74dde330
~~~

Reconcile the current `origin/develop` tip with the task base without rewriting any shared history. If necessary, refresh the local `develop` through its authorized workflow before creating the task worktree; otherwise bring the current develop changes into your isolated task worktree without touching the primary checkout. Determine whether new fork commits already implement some approved features and **integrate, do not duplicate, those implementations**.

Carry the decision documents into the task worktree (e.g. selectively copy/restore `docs/migrations/upstream-v4.6.1/` from the planning branch into a clean worktree, and commit that documentation import separately before starting the merge), or read them directly from the planning ref. Never merge the planning branch solely to obtain its docs.

On a clean task branch/worktree, initiate a **real** merge:

~~~bash
git merge --no-ff --no-commit 5b04bf6a164f028d41701299367d0dde74dde330
~~~

Resolve all conflicts based on the approved behavior, compile/test the resolved candidate, and commit a **genuine two-parent merge** once consistent (e.g. `chore: merge upstream v4.6.1`). Subsequent focused adaptation commits are fine. If the merge cannot be completed safely, leave a clear local handoff rather than committing an incomplete merge. Check:

~~~bash
git merge-base --is-ancestor 5b04bf6a164f028d41701299367d0dde74dde330 HEAD
git status --short
git log --merges --oneline -n 5
~~~

**Do not push or merge the task branch into `develop` or promote to `master` without separate authorization and the full suite on the final combined candidate.** No release delivery/publication is part of this task. For an actual approved future upstream synchronization into `develop`, follow the repository's real-merge procedure rather than ordinary squash-task integration.

## 3. Coverage map: implement all 68 IDs

The table below partitions the 68 **approved** items into dependency-oriented implementation work. It is not a replacement for the full decision descriptions; read the source sections for every ID. A topic whose approved resolution is **do not copy / retain Fork** still requires deliberate conflict resolution and validation.

| Group / order | IDs (each belongs to exactly one group) | Goal |
| --- | --- | --- |
| 1. App foundations and data invariants | `X01–X03, A01, A12` | Bootstrap/runtime/headless seams while protecting profile UUIDs, canonical PostOrigin, bookmark snapshots and identity, persisted folders and Following |
| 2. Media cache / native / format | `X04, A09, A18` | Simplify image cache without generations, keep origin-safe MD5/LRU; cache paths/DocumentsProvider and AVIF fixes |
| 3. Network and browser | `N01–N06, A07–A08, A10` | One coordinated request-admission/rate-limit layer, HTTP retries and security, Cloudflare/cookies, media hosts, diagnostics/logging and Windows WebView |
| 4. Core UI/platform foundations | `A02–A06, A11, A13, A17` | Kurumi migration/animation, responsive Settings, privacy defaults, localizations, optional NixOS assets, skip reverted/no-op changes |
| 5. Booru behavior | `B01–B10` | Sankaku, Shimmie2, Gelbooru/Rule34, Nozomi and site-specific compatibility |
| 6. Grid/viewer/search UX | `P01–P14, U01–U08` | Dual quick actions, video/GIF behavior, input/selection/gesture/hover semantics, keyboard/D-pad/TV best-effort, search keyboard usability |
| 7. Downloads, exports and persistence | `D01–D08` | Durable optional sidecars, background and bulk download lifecycle, Anime-Pictures/Zerochan bulk, real source IDs, stable backups |
| 8. CI, signing and release identity | `A14–A16` | Toolchain/native build reconciliation, **retain fork signing identity**, version scheme, changelog, What's-New and updater |

Implement dependency-first but do not let these groups create duplicate services. At critical boundaries (runtime, bookmark/backup, network, downloader, Kurumi/navigation), verify before proceeding.

## 4. Non-negotiable merge rules / known traps

### Identity, storage and backup (`X01–X03, D07, D08, A01`)

- **Hive collision:** fork `BookmarkHiveObject` indices **15 = `snapshotSchemaVersion`** and **16 = `postSnapshot`**; upstream's new index 15 = `sitePostId` is incompatible. **Keep the fork mapping exactly.** Do not introduce a new Hive field for `sitePostId`.
- Add a shared `Post.sitePostId: String?` getter for the genuine upstream/site identifier. For Sankaku prefer stored `SankakuPostData.sankakuId`, including alphanumeric IDs; missing genuine IDs remain null (never masquerade synthetic `Post.id` as genuine). For Pixiv return the real artwork/`illustId`, not the synthesized per-page ID. Avoid core importing individual booru implementations directly.
- **Approved filename behavior:** switch the existing `{id}` token to the actual `sitePostId`; **do not** introduce `{site_post_id}`. Old filename compatibility is explicitly **not required**. Pixiv's existing default `{illust_id}_p{page}.{extension}` **must stay unchanged** so artwork pages are named distinctly. Guard custom `{id}`-only collisions and missing site IDs; never silently overwrite existing files.
- Current bookmark backup is format **v5** (import accepts v4/v5); the true Sankaku ID is already in `StoredPostSnapshot.custom.sankakuId`. Keep `BookmarkIdentity(site, postKey)`, `PostOrigin`, profile UUIDs, bookmarks/groups/nested folders, Following and Pinned Searches. Do **not** substitute the upstream's old bookmark/profile/backup model or silently change export/import behavior.
- D08 full favorite-tag backup reads persistent repository via `getAll()`, not a possibly cold/uninitialized UI provider; preserve label data and existing `replaceAll` import semantics.

### Cache, sharing, GIF and video (`X04, A09, P06–P09`)

- **Image cache:** keep the fork's URL-MD5 key, origin isolation, disk quotas/LRU/journal/checkpoints; remove physical `.generation_` files/generation scheme. When concurrent downloads produce the same already-valid file, discard the duplicate; remove and redownload corrupt entries. For image sharing, copy to operating-system temp/cache space (`boorusama-share`), use existing >24h cleanup rather than inventing a new long-lived cache subsystem. Preserve native read-only cache DocumentsProvider behavior.
- **Video cache is different:** P08 demands a temporary **active-use lease/refcount** for cached files so LRU/expiry/clear does not delete the video while WebView/player reads it. Release on dispose/source switch/failure; support streaming fallback. Do not reintroduce **image** generations as a supposed solution.
- **GIF grid playback cap:** automatically load an animated GIF (including animated Danbooru samples) **only** when autoplay is enabled **and original GIF file size is known, positive and ≤ 5 MiB = 5×1024×1024 bytes**. Unknown/zero or larger means static thumbnail **even with Highest selected**. No extra HEAD/original download merely to discover length. Existing GIF Automatic-vs-manual Highest Danbooru variant selection is **not** to be silently changed. Normal post viewer and explicit downloads are exempt.
- Video poster remains until first rendered frame, with race-safe source switches (P07). Viewer at 1× favors PageView swipes; zoomed images permit pan and preserve the fork's 160dp edge-pull, double-tap, pinch, original-on-zoom and other custom gestures (P09).

### Network, security, sites (`N01–N06, B01–B10, D05–D06`)

- `ApiRequestCoordinator` remains **the single** per-origin admission/pacing/priority/429-cooldown authority. Integrate upstream Retry-After, timeout/cancellation and site policies; **do not add its `SlidingWindowRateLimitInterceptor` as a second queue** (especially Zerochan, Anime-Pictures and E-Shuushuu). Keep active browsing more responsive than Following/preload/bulk.
- Never forward cookies/Authorization indiscriminately across custom media-host overrides. Treat Cloudflare and network mutations as non-idempotent unless proven safe; do not automatically replay favorites/votes/comments/POSTs after challenges.
- Sankaku changes include metatags and date filters, full site-specific tag categories, error handling and safe auth recovery. Do not build a second legacy search bar; adopt typed suggestions inside the fork's common search options model.
- Gelbooru v2 / Rule34: preserve comment pagination and site-gated ordering; implement **upvotes, not invented downvotes**. No blind replay for mutating vote URLs.
- Rule34 new API-host for listing (`B10`) **must be confirmed against live endpoint behavior and fork cloudflare/Auth/request constraints before switching**; fallback to existing functioning host when verification does not justify the change.
- Zerochan download resolution (`D06`): explicit original requests must **never silently fall back** to preview/sample; use site/Asiachan HTML fallback only when needed, safe concurrent-request coalescing, and N01 pacing. Anime-Pictures (`D05`): support bulk, remove stale unlimited URL cache but preserve bounded fork extractor cache with authentication/expiry checks.

### Post grid, search, input and UX (`P01–P05, P10–P14, U01–U08, A02–A04`)

- P01 two configurable quick actions, with careful legacy one-button migration. Resolve the fork's **`PostGridItemAdditions.quickActionButton` / `BooruPostPresentation` per actual `post.origin`** for every Default action, especially mixed-origin feeds and Danbooru banned posts. Never resolve favorite behavior solely from the currently selected profile. Preserve tile selection/series grouping.
- Preserve the fork's `PostGridController` refresh queue flags and waiter semantics. Integrate upstream stale-result protection **in addition**, not in place of that queue (P04).
- Preserve `BookmarkViewRefreshGate` as the only post-mutation refresh path; do not add a duplicate upstream listener (P05).
- Menu/selection hierarchy: retain Hold-and-Drag, long press, right click, Series-grouped cards, bookmark group actions, Following, undo, and no tap-through. Kurumi context menu, focus, accessibility and Escape/Android Back dismiss **one innermost visible layer at a time**.
- Upstream search keyboard fixes and Listbox (U01–U03) integrate with the fork's planned compact term-specific Raw Editor, typed tag/metatag suggestions and automatic search. Do not regress existing query/session state, selected tags, search profile switch or Following.
- D-pad, focus rings, Tab navigation and scroll reveal are broadly useful; TV support is **best effort, not a new officially supported platform** (U04).
- P03 error Retry must cooperate with `ProgressivePostImage`; preserve already loaded fallback images and tile opening gestures. P12 previews open from Info badge, not whole tile. P10 only consumes volume navigation keys with eligible visible viewer/settings. P11 hardware play/pause only for visible player. P14 Quick Action keyboard accessibility and Selection precedence.

### Downloads and sidecars (`D01–D04, D07–D08`)

- D01 opt-in **Off (default) / TXT / JSON** sidecars; global format with per-bulk-task override, **not** a profile-specific setting. Sidecars are immutable snapshots of the genuine post metadata and safe public source URLs (no credential/token leaks); publish atomically **after confirmed media completion**. An existing file skipped by `skip if exists` does not trigger unsolicited sidecar generation. Sidecar failure/recovery/retry should not redownload or overwrite the media. Keep failure/retry visible and durable across background isolates/restart.
- D02 final upstream session completion algorithm plus existing fork lifecycle/notification guards: serialize concurrent session completion, snapshot stats before cleanup, tolerate file-size failure, handle restart/crash/replays idempotently and bound notification completion history.
- D03 update pinned `khoadng/background_downloader` git dependency **`e8ad9f9` → `fd67fff9ee4ad4cdf415dc3285289cad9289cefe`** only after source/API/native/Cronet compatibility checks. The package still says v9.6.1; pin and lockfile must agree.
- D04 injectable `DownloadTaskClient` for tests, copy each task group list before immutable state replacement, and ensure the broadcast stream controller has one owning disposer; keep fork networking/auth/DownloadActivity integration.

### Release/platform invariants (`A06, A14–A16, X03`)

- Preserve package/application ID **`com.timberpile.boorusama`**, flavors, signing key, existing signer certificate, release/update channel, split APK handling and default privacy/lock settings and user overrides. **Never** replace fork signing with the upstream's key.
- Do not resurrect reverted upstream Settings Search (`A05`); keep the fork's Settings Search and dynamic header titles.
- Integrate the useful What's-New repeated-popup fix while preserving existing fork changelog and user-visible release notes.
- Use pinned `fvm` Flutter SDK; investigate native/Gradle issues without changing the fork's identity, Rust/AVIF and platform assumptions or swallowing CI failures.

## 5. Newly finalized versioning policy (`A16`)

The user specifically approved **an upstream-synchronized base version and a per-base Timberpile release counter**, superseding prior guidance that always increments the Timberpile suffix while keeping `4.5.0`:

- Version **name** format: `<upstream-MAJOR.MINOR.PATCH>-timberpile.<N>`.
- Use exactly the upstream release version **actually merged** (for this task **4.6.1**).
- On the **first** Timberpile release built on a new upstream version, reset `N = 1` (**not zero**); for subsequent releases with the same upstream base, increment `N`.
- The Flutter **base build number** (after `+`) is **strictly monotonically increasing** across *all* fork releases, even when `N` resets. Android split APKs can add ABI-specific versionCode offsets, so confirm each resulting APK's effective code increases relative to its applicable previously installed/staged store artifact; the base `+190` need not exceed all ABI-offset APK codes.
- Current verified `pubspec.yaml`: **`4.5.0-timberpile.5+189`**. Assuming no intervening published version/build code, prepare **`4.6.1-timberpile.1+190`** for the first finished v4.6.1-based fork release. **Inspect current release tags, highest previously allocated base build number, effective per-ABI APK codes and any Play Store codes before deciding the actual number**.
- Subsequent same-upstream release: e.g. `4.6.1-timberpile.2+191`. Next upstream base (hypothetical v4.6.2): `4.6.2-timberpile.1+192`, if sequential.
- Keep the historical fork `CHANGELOG.md` entries; append the real user-visible new release notes at the top, with heading `# 4.6.1-timberpile.1`; never replace the fork changelog with the upstream changelog.
- Keep tag naming `v4.6.1-timberpile.1` and GitHub updater manifest `version` consistent; compare app update versions using existing SemVer implementation, and ensure update detection succeeds from `4.5.0-timberpile.5` to `4.6.1-timberpile.1` despite the fork counter reset. Check APK `versionCode` (including ABI-specific build-code rules), package ID and signer when validating upgrade.
- **Update `.agents/skills/prepare-release/SKILL.md` and relevant release-preparation/version tests** to encode this rule. Its current default guidance to *always* bump `timberpile.N` and preserve the old upstream base is obsolete for upstream upgrades. Adjust code/tooling only as needed; do not run the legacy release CLI/scripts excluded by the prepare-release skill.
- Version preparation, changelog, artifacts and manifest verification are part of migration readiness. **Actual publishing, remote tagging and GitHub draft creation remain separately authorized operations.**

## 6. Verification / completion contract

During implementation, run affected widget, package, persistence and contract tests immediately. Use `fvm dart format` on touched Dart files; `./gen.sh` only for changed generation inputs or missing generated files. Follow repository localization/code style. Do not turn compile failures into exclusion or remove fork tests to make the suite green.

**Before claiming a merge candidate safe to integrate, run on its FINAL combined tree**:

~~~bash
./scripts/run_regression_tests.sh
git diff --check
git status --short
git merge-base --is-ancestor 5b04bf6a164f028d41701299367d0dde74dde330 HEAD
~~~

The full regression runner includes the Flutter app suite, **every package including CLI**, PR/release policy scripts and Python tooling tests. See `docs/engineering_guidelines.md`. Run Android/native build and targeted upgrade/signer checks when facilities are available. Do not treat the limited local environment, CI, unit tests, an unverified historical trial merge or manual tapping as evidence of completed production upgrade.

Specific mandatory regression categories:

1. **Data:** old and new Hive bookmark read/write (15/16), v4/v5 backup and import, profile UUIDs, site-specific IDs (Sankaku strings, Pixiv pages), group nesting/default groups, Following/Pinned Search refresh, backup crash recovery and profile switching.
2. **Network/browser:** priority/coordinator admission, 429 cooldown, Retry-After seconds/date, request cancellation, safe Cloudflare retries, cookies/host boundaries, site's auth and large search/bulk calls.
3. **Media:** URL-MD5/cache eviction/corruption/parallel fetch, sharing from temp copy, DocumentsProvider only valid files, 5 MiB GIF boundary and missing size, poster-to-first-frame races, playback while cache clear, ZoomEdge/PageView gesture arbitration.
4. **UX:** per-origin two quick actions and legacy settings, hover/info badge, Selection/Hold-and-Drag/right click, stale/queued grid refresh, search keyboard/Raw Editor/Tag Listbox, sheet overlays and focus/Escape/D-pad and Settings navigation.
5. **Downloads:** sidecar completion and crash/retry/skip, duplicate metadata, single vs bulk vs cache; immutable task state/stream ownership; Anime-Pictures and Zerochan original resolution and rate limits; download resume/notifications.
6. **Release:** SemVer ordering on upstream base jump, fork counter reset, monotonic build number, `pubspec.yaml`/changelog/manifest synchronization, what's-new-once, identity/signing/ABI APK upgrade checks.

**A02 explicit user preference:** Once UI implementation is done, **the agent writes a short prioritized manual acceptance checklist for the user to execute**. The agent does NOT perform the user's manual UI checks. Automated tests, headless flow tests and feasible build checks are still the agent's responsibility. If emulator checks are genuinely necessary, first comply with `docs/android_emulator.md` lease rules; do not present a simulation as the user's acceptance.

## 7. Done means

- A real upstream v4.6.1 merge commit with correct ancestry; no unresolved conflicts or truncated subsystem rewrites.
- Every one of the **68 IDs** implemented according to `decisions.md`, or deliberately retained/skipped exactly where the approved resolution says so. No silently lost fork features.
- All required data migrations and backward compatibility **as specified**, with regression coverage and no accidental site/post identity changes.
- The finalized **A16** version convention implemented in release preparation and tests; appropriate candidate version and accurate changelog/manifest prepared, but no unauthorized release/push.
- Targeted suites + **complete** repository regression runner passing against the final candidate, or precisely documented blockers if incomplete. Any test failures are not described as success.
- UI manual acceptance checklist prepared for the user.
- Worktree with focused commits, clean Git status, an implementation report linking its commit SHAs and test results, remaining issues/limitations, and any separate integration/release authorization needed.

**Do not stop after making a draft plan.** The user has approved the migration implementation. Carry out the work, preserve real ancestry, solve conflicts and verify results in your local task worktree. If full completion is blocked by new facts, leave a precise reproducible handoff specifying the failing commands/files and next actions, not a claim of finished integration.
