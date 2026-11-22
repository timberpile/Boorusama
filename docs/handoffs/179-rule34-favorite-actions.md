# #179 — Favorite review, remediation, and remaining verification

## Branch and baseline

Continue `timberpile/Boorusama` branch **`bug/179-rule34-favorite-actions`**.
Reviewed implementation: `f427f896e58a447e040cd7381b375b331ffdc5a1`.
The review covered the #179 changes, shared Favorite observations, changed engine
consumers, UI actions, and adjacent tests. Unrelated work replayed from develop
was retained, not rewritten as part of the Favorite repair.

The branch already contains the changes from `develop@d9203ae62dcbc5ff81e0bd70702607fb24070787`
through cherry-picks, including the group toolbar/overflow controls. GitHub's
three-dot comparison therefore includes replayed changes; divergence alone is
not evidence those changes are missing. Inspect actual trees before integration.

This handoff supersedes the initial research guidance in this path and the
intermediate pagination-based plan. Keep the existing `rule34-session-v1:`
credential representation and its `r34_uid` / `__Host-session` transport.
Do not restore legacy Rule34 `user_id` / `pass_hash` cookies.

## 22 November 2026 continuation

The task worktree was fast-forwarded to the published remediation at
`9147135519ba945d6d83a7228883992af5085f41`. A new Kurumi menu regression
reproduced a disposed `WidgetRef` after an access-bound menu closed during
the first Favorite mutation. Action snapshots now revalidate the captured
account and content access through the action owner's provider container.
The tests cover menu dismissal, account deletion before the next dispatch,
account replacement during the last dispatch, and a quick-heart/menu race
followed by a successful retry.

During the initial probe, the ordinary website login route returned a
Cloudflare HTTP 403 challenge in host Chromium. On leased
`emulator-5554`, the debug probe APK built, but both install attempts and Maestro
timed out. The installed APK still matched the previous build at lease release.
The probe APK remained staged in the device's temporary directory. This session
captured zero authenticated deletion responses.

Local verification of the continuation used Flutter 3.47.2 and six test workers.
Formatting checked 16 Dart files. Affected analysis exited 0 with one existing
informational lint on the share action. The focused app run passed 791 tests,
and a separate run passed the four Danbooru vote regressions after the
authenticated fixture correction. The standalone `booru_clients` Dart suite
passed 303 tests.

`./scripts/run_regression_tests.sh` exited 0 on the final runtime and test tree.
It passed 8,064 app tests, 1,790 tests across 13 package and CLI suites, 39 PR
policy checks, 20 Android release script checks, and 76 Python tests. The
`go_router` suite retained two pre-existing skips. Local evidence is under
`.worktrees/_artifacts/179-rule34-favorite-actions/`.

## HTTP 200 follow-up

The owner observed HTTP 200 both when removing a Favorite and when the post
was already absent, and approved that status as the removal acknowledgement.
The client accepts HTTP 200 after its origin and login-response checks.
Removal dispatches one request. The status alone cannot establish whether that
request changed server state. Independent authenticated device acceptance
remains unverified.

Formatting checked three Dart files and affected analysis found no issues.
The focused run passed 304 app tests, and the complete `booru_clients` Dart
suite passed 301 tests. `./scripts/run_regression_tests.sh` exited 0 with 8,065
app tests, 1,788 tests across 13 package and CLI suites, 39 PR policy checks,
20 Android release script checks, and 76 Python tests. The `go_router` suite
retained its two existing skips.

## HTTP 302 follow-up

The owner reproduced the failure on the HTTP 200 build and saw HTTP 302 in
Boorusama's Network log. The successful browser capture showed one GET to
`/index.php?page=favorites&s=delete&id=<postId>&return_pid=0`. Its response
redirected to `index.php?page=favorites&s=view&id=<accountId>&pid=0` for the
same account as the referring Favorites page. The browser then received
HTTP 200 with a Favorites page that omitted the deleted post.

The client now sends `return_pid=0` and accepts the captured HTTP 302
shape when the same HTTPS origin, account, and first-page offset match.
It dispatches one mutation. Login redirects indicate session rejection, and
other redirects leave the removal unconfirmed. The retained browser evidence
contains only sanitized route shapes and statuses. The emulator install timed
out and the installed APK hash still matched the prior build.

Affected analysis found no issues. The focused app run and the complete
`booru_clients` Dart suite each passed 305 tests.

## Published remediation at `9147135519`

### 1. Remove the collection crawl from Rule34 removal

`packages/booru_clients/lib/src/gelbooru_v2/rule34_favorite_actions.dart`
previously searched up to ten pages before deletion and scanned again afterward.
Its paginator, script, thumbnail, and neighboring-post checks coupled a single
mutation to collection size and an unverified authenticated HTML layout. The
reported device attempt stopped on the first pre-delete HTTP 200 response.

The client now sends **one existing GET mutation**:
`/index.php?page=favorites&s=delete&id=<postId>`.
There is no prerequisite listing read, verification crawl, pagination budget,
post-location scan, or automatic replay. Add/remove retain explicit HTTPS-origin
checks, disabled redirects, private diagnostics, profile-cookie precedence, and
state-changing request classification. State-changing GETs request no caching.
Multiple Location values no longer cause the response parser to throw a header
access error.

At publication, the client accepted an empty HTTP 204 as an explicit no-content
success based on a synthetic fixture. It treated HTTP 200 and Favorites redirects
as unconfirmed. Known login rejection and forbidden responses had distinct
outcomes.

An unconfirmed response may follow a deletion that the server already performed.
The existing repository/notifier rollback keeps the last observed state; it is
not proof that the server still has that Favorite. Positive-only page observations
cannot establish its absence. Do not tell the owner that live removal is fixed
until the remaining contract/verification work below is completed.

### 2. Fence stale observations per Post, not per whole account

`lib/core/posts/favorites/src/providers/favorites_notifier.dart` previously
invalidated an entire read when any Favorite mutation started or settled. Changing
Post A could discard valid Favorites from an unrelated page containing B and C.

A per-Post mutation revision now rejects only observations for affected IDs.
Reads started before or during A's mutation cannot overwrite A, while unrelated
IDs remain useful. Existing read-order checks, provider-lifetime fencing,
anonymous-read exclusion, account/credential isolation, and unknown-state
semantics remain intact. A lookup returning IDs outside the requested set is
ignored rather than manufacturing negative results for the requested IDs.

### 3. Prevent same-Post mutation overtaking

Opposite commands could previously be dispatched concurrently. A local sequence
number cannot force the server to commit requests in that order. The shared
notifier now refuses additional add/remove commands for a Post while its current
mutation is pending; it does not silently queue or replay them. Different Posts
remain independent. Capability checks now occur at the mutation boundary as well
as in the UI.

The interruption tests were changed to assert this single-in-flight contract,
not to preserve the old concurrent dispatch behavior. They retain rollback,
unknown-state, cancellation, and cooldown coverage using explicit completers.

### 4. Preserve a completed Add when cleanup is interrupted

The Add path now handles `FavoriteCompletedWithInterruption` symmetrically with
Remove: preserve acknowledged state, report cleanup interruption through the
existing feedback collector, and propagate the completion signal outside that
collector. A completed server action must not be rolled back or retried merely
because its separate cleanup was interrupted.

### 5. Handle ordinary transport failures at the shared UI boundary

`lib/core/posts/favorites/src/widgets/favorite_action.dart` now handles ordinary
Dio errors with the existing localized failure feedback instead of rethrowing
them into unawaited UI callbacks. Cancellation/cooldown behavior is preserved;
error bodies, request parameters, and exception messages are not shown. Stale
account feedback remains suppressed. Programming errors are not broadly caught.

### 6. Retain a live owner for bulk Favorite actions

`lib/core/posts/listing/src/widgets/post_actions.dart` now checks account identity
through the longer-lived feedback container rather than a potentially disposed
menu WidgetRef. Favorite services are resolved there against the explicitly
captured auth/profile. The identity guard is checked before each mutation and
before final success/error feedback, and is also passed to `runFavoriteAction`.
Closing a menu must not itself break the remaining selection; changing/removing
its account must prevent subsequent dispatch and stale feedback.

## Tests and actual verification status

New tests:
- `test/core/posts/favorites/favorite_mutation_regression_test.dart`: per-Post
  observation fencing, unrelated conclusive lookups, invalid lookup results,
  capability rejection, and completed-Add cleanup interruption.
- `test/core/posts/favorites/favorite_action_error_test.dart`: transport error
  feedback, cancellation, private-message exclusion, and obsolete account feedback.

Updated tests:
- `packages/booru_clients/test/gelbooru_v2/rule34_favorite_actions_test.dart`:
  single physical mutation, no collection dependence, synthetic 204, ambiguous
  200/redirects, session rejection, malformed Location headers, no replay,
  unchanged Add semantics, and legacy-site compatibility.
- `test/core/posts/favorites/favorite_interruption_test.dart`: same-Post exclusion
  and exact rollback on interruption.
- `test/core/posts/favorites/favorite_observation_test.dart`: unmodified IDs from
  an older read are retained rather than discarded by another Post's mutation.
- `test/boorus/gelbooru_v2/rule34_favorite_provider_test.dart`: rejected deletion
  now reaches the delete request directly, without the removed preflight read.

This remediation was source-reviewed. The execution environment has no `fvm`,
Flutter, or Dart: the targeted test command could not start (`fvm: command not
found`). No Flutter/Dart test pass, analyzer result, formatter result, APK build,
or authenticated device verification is claimed for this revision. Static
patch checks and state-machine counterexamples are not application tests.
The owner's reported full pass on the earlier candidate does **not** qualify
this changed runtime candidate.

## Original verification checklist

### A. Investigate the Rule34 deletion receipt

The HTTP 200 follow-up records the current Rule34 deletion decision.

1. Follow `AGENTS.md` and the emulator lease procedure if device access is needed.
   Use only the existing authorized test account; do not expose its credentials.
2. Compare a controlled successful browser removal with one explicit app removal
   of a known Favorite. Determine the actual request method/parameters and
   response status, body *structure*, and redirect category. Do not change the
   endpoint or import a different site's status-code semantics on speculation.
3. Inspect the site's outcome independently for that one Post. This is diagnostic
   acceptance work, not permission to introduce an automatic collection scan or
   to call Add as a supposedly read-only membership probe.
4. Establish how an actual success differs from expired login, denial, an already
   absent Post, generic HTML, and an interrupted response. Add sanitized fixtures
   derived from those observations. Never commit raw authenticated HTML, cookies,
   signed IDs, headers, or private response logs.
5. Implement the smallest evidence-supported receipt parser or genuinely targeted
   verification if required. Preserve one mutation dispatch and constant request
   cost; any extra targeted read needs a verified contract, not a pagination cap.
6. Where the protocol cannot establish an outcome, preserve uncertainty and
   explicitly report the remaining limitation. Never restore the ten-page scan
   or claim a synthetic success fixture proves the live behavior.

### B. Run the changed candidate locally

Use the existing isolated task worktree and reconcile this commit with any local
changes without resetting or force-pushing. Use FVM per repository instructions.

```bash
git diff --name-only -z --diff-filter=ACMRT \
  f427f896e58a447e040cd7381b375b331ffdc5a1 HEAD -- '*.dart' | \
  xargs -0 fvm dart format
workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$workers" \
  test/core/posts/favorites \
  test/boorus/gelbooru_v2/rule34_favorite_provider_test.dart \
  test/boorus/gelbooru_v2/rule34_session_import_test.dart
(cd packages/booru_clients && fvm dart test "--concurrency=$workers")
```

Also run the affected HTTP replay/protection/log-redaction tests, server-Favorite
projection tests, and selection/toolbar/menu consumers. Analyze the affected
scope. Validate these concrete UI/lifetime cases, adding widget regressions where
coverage is missing:
- Close the menu while the first of several Favorite mutations is pending; the
  remaining selection completes without a disposed-ref error.
- Replace/delete the originating account during the final mutation: no subsequent
  request and no success, failure, or cleanup toast for an obsolete account.
- Exercise rapid opposite commands through two entry points, then retry after the
  first settles; exactly one request is in flight for that Post.
- Own-page observations update the grid, viewer, overflow, and menus without
  extra mutations, bookmark projections, or loss of unrelated observations.

Before any separately authorized integration, run
`./scripts/run_regression_tests.sh` on the final combined candidate. Record actual
commands, results, skips, checked commit/state, and live-site limitations.

## Boundaries

No new durable Favorite database, background synchronization, source-alias
inference, or extra issue tracker is needed. Favoriting is separate from local
Bookmark Group membership. Retain the present auth-scoped RAM cache and existing
confirmed-result projection. No PR, merge into develop, issue closure, branch
deletion, or history rewrite is authorized by this handoff.
