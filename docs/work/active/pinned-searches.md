# Implementation Handover: Pinned Searches MVP

## Objective

Implement the approved Pinned Searches MVP completely by following:

1. `docs/superpowers/specs/2026-09-14-pinned-searches-design.md`
2. `docs/superpowers/plans/2026-09-14-pinned-searches.md`

The implementation plan is divided into nine ordered, behavior-first tasks.
Work through them in order and update each plan checkbox only after its step has
actually been completed and verified.

## Repository and branch

- Repository: `timberpile/Boorusama`
- Branch: `feature/pinned-search-subscriptions`
- Existing isolated worktree: `/tmp/boorusama-pinned-search-subscriptions`
- Base: `origin/develop` at `1f68fc0ef`
- Latest handover commit: the commit containing this file

Do not implement this work in the main checkout if it contains another task.
Do not reset, stash, clean, or overwrite unrelated work.

There is an obsolete local branch named `feature/pinned-searches`, based on an
old project baseline. It specifies a different bookmark-like feature without
manual new-post checking. Do not cherry-pick it, merge it, copy its OpenSpec
files, or treat it as current requirements.

## Required workflow

1. Read the repository `AGENTS.md` and `docs/development_workflow.md`.
2. Read the approved design and the entire implementation plan above.
3. Use `superpowers:subagent-driven-development` when agent delegation is
   available, or `superpowers:executing-plans` for inline execution.
4. Follow test-driven development for every behavior change: add the focused
   failing test, verify the expected failure, implement the minimum behavior,
   and verify the test passes.
5. Run `fvm dart format` immediately after creating or changing Dart files.
6. Make focused conventional commits at the end of each completed plan task.
7. Do not push, open a pull request, merge, or delete branches unless the user
   explicitly requests that delivery action.

Use `fvm` for every Flutter and Dart command. Before the first `./gen.sh` in
this fresh worktree, run:

```bash
cd packages/boorusama_cli
fvm dart pub get
cd ../..
```

## Fixed MVP behavior

- Pinned Searches is app-local and separate from server-owned saved searches.
- A pin belongs to exactly one `BooruConfig.id`.
- The page is a flat, manually ordered list for the active profile.
- Pinning opens a dialog with an optional custom name and no folder control.
- Blank names persist as `null`; display falls back to the exact stored query.
- The query is immutable after pinning.
- Pinning saves first and then performs a user-initiated initial snapshot.
- The first successful snapshot establishes a checkpoint, caches up to four
  previews, and produces zero unread results.
- If the initial snapshot fails, the pin remains saved. Its first later
  successful manual refresh establishes the baseline with zero unread results.
- Later manual refreshes count only previously unknown matching posts whose
  upload timestamp is strictly after the previous successful checkpoint.
- Old posts that begin matching because of tag, score, status, or other edits
  do not count as new.
- Opening a pin atomically clears its currently known unread count before
  opening the unchanged query through the normal search flow.
- Users can refresh one pin or Refresh All for the active profile.
- Refresh All starts never-refreshed searches first, then orders by oldest
  `lastSuccessfulCheckAt`, with stable subscription ID as the tie-breaker.
- Batch refresh uses bounded concurrency and continues after individual
  failures.
- Search and navigation badges show active-profile unread counts. The list
  displays only cached state and never refreshes merely because it was opened.
- Deleting a profile deletes all of its subscriptions, preview data, and recent
  deduplication identities. There is no recoverable orphan state.
- Backup contains definitions, optional names, profile mapping, and relative
  order. It excludes previews, recent IDs, checkpoints, unread counts, attempts,
  and errors.
- Portable profile identity strips URL user info, query, and fragment to avoid
  exporting embedded credentials. It retains scheme/host/port/path, lowercases
  the host, and removes all terminal path slashes idempotently. Export, parsing,
  restore mapping, and profile replacement use this same identity.

## Explicitly deferred

Do not implement any of these in the MVP:

- folders or folder selection;
- nested folders;
- automatic, periodic, launch-time, resume-time, or operating-system
  background refresh;
- refresh interval settings or retry scheduling;
- device notifications;
- cross-profile result aggregation;
- combined following feeds;
- hidden feed-owned searches;
- local emulation of complete booru query semantics.

The approved design contains the intended later behavior for single-level
folders, automatic refresh across all configured profiles, and scalable
single-profile combined feeds. Preserve the seams specified by the plan, but do
not add speculative fields, services, or UI for those phases.

## Important implementation boundaries

- Persist each subscription and its bounded preview/recent-ID data as one Hive
  aggregate so a refresh checkpoint, unread count, and previews commit together.
- Keep storage behind `SearchSubscriptionRepository`.
- Keep refresh orchestration in `SearchRefreshService`, not widgets or the
  Riverpod notifier.
- Expose chronological refresh planning through `BooruRepository`, with a
  conservative default and explicit unsupported outcomes.
- Treat nullable post timestamps as unsupported for a successful chronological
  scan; never infer an upload time from the device clock or post ID.
- Failed or incomplete scans preserve the prior successful checkpoint, unread
  count, and previews.
- Coalesce concurrent refresh requests for the same subscription.
- Reload the current aggregate during refresh commit so mark-read or rename
  operations racing a refresh are not overwritten.
- A refresh completing after mark-read may add newly committed unread posts.
- Reject stale successes and failures if the subscription was deleted or its
  immutable `createdAt` changed. Backup import can recreate the same UUID with
  a null checkpoint, so UUID/checkpoint alone does not identify an incarnation.
  Successful commits must also match the captured checkpoint. Runtime rollback
  preserves the captured aggregate and its original `createdAt`.
- Use manually declared Riverpod `Notifier`/`AsyncNotifier` providers only.
- Put all user-facing copy in i18n and access it through `context.t`.
- Parse backup and remote data defensively with explicit nullable handling.

## Existing code seams to reuse

- `lib/core/posts/post/src/types/post_repository.dart` for post retrieval.
- `lib/core/posts/post/src/types/post.dart` for generic post identity,
  timestamps, and preview URLs.
- `lib/core/boorus/engine/src/booru_repository.dart` and
  `lib/core/boorus/defaults/src/booru_repository_default.dart` for refresh
  capability exposure.
- `lib/core/search/search/src/widgets/search_page_scaffold.dart` and
  `lib/core/search/search/src/widgets/search_controller.dart` for the loaded
  query and result-header pin action.
- `lib/core/search/search/src/routes/route_utils.dart` for reopening the exact
  query.
- `lib/core/images/booru_image.dart` for authenticated cached previews and
  image fallback behavior.
- `lib/core/bookmarks/src/providers/bookmark_provider.dart` for serialized
  AsyncNotifier mutation/state-publication patterns.
- `lib/core/bookmarks/src/data/hive/` and `lib/core/hive/hive_adapters.dart` for
  Hive repository and generated-adapter patterns.
- `lib/core/configs/manage/src/providers/booru_config_provider.dart` for the
  profile-deletion cascade.
- `lib/core/backups/sources/` and `lib/core/backups/sources/providers.dart` for
  validated backup sources and registration.
- `lib/core/routers/routes.dart`, `lib/core/home/src/widgets/side_bar_menu.dart`,
  and `lib/core/home/src/pages/home_page_scaffold.dart` for routing and mobile/
  desktop navigation.

## Verification requirements

Run the focused command listed in every plan task before committing that task.
At the end, run at minimum:

```bash
fvm dart format lib test
fvm flutter analyze
fvm flutter test test/core/search/subscriptions test/core/backups/pinned_search_backup_codec_test.dart test/core/backups/pinned_search_import_service_test.dart test/core/backups/pinned_searches_source_test.dart test/booru_config_notifier_test.dart
fvm flutter test
git diff --check
git status --short --branch
```

Also perform the manual behavior checklist in Task 9 when the environment can
run the application. Report manual verification separately from automated
tests; do not claim it happened when the environment did not support it.

If full-suite verification exposes an unrelated pre-existing failure, preserve
the exact failure output, confirm the focused feature suite independently, and
do not weaken or skip tests to obtain a green result.

## Completion report

Finish with:

- the observable behavior implemented;
- focused test, analyzer, generation, and full-suite results;
- manual test results or the precise environment blocker;
- remaining risks or unsupported booru/query cases;
- the final plan checkbox count;
- branch status and latest commits.

If the current architecture makes an approved requirement impossible without a
material scope increase, stop at that boundary and report the concrete conflict
instead of silently weakening the specification.
