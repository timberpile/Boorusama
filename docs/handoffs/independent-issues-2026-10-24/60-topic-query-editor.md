# Issue #60 — Update the original Topic from Search

## Source and delivery boundary

- Source task branch: `feature/60-topic-query-editor`; retained here as completed implementation history.
- Origin-switching follow-up commit: `7184ef9232b6570ecd0547b623cc2ffe64f746c6` (`fix: switch active Topic after following a query (#60)`).
- The underlying Search update workflow was implemented in `26657f7064844db3d66d9b89a8ad2c109b1d730b`; its complete-regression and Android evidence below is historical for the follow-up.
- This workflow replaces the dedicated query editor in `5d7de6906`, `786aaf4e0`, and `abce0092a`. Those commits' Android and test evidence is historical.
- Incorporated develop baseline: `6d7e988fde16c2b3187afad41614cf1197591a6b`, through merge `b97502ee31d159fc0a24fb394714c27c09a318b9`. Current develop has not been combined with this candidate.
- The user approved develop integration, publication, issue closure, and completed task cleanup. Earlier local-only limits and pending integration notes below describe historical verification stages; the final combined-candidate record supersedes them. No PR was requested or created.

## Current behavior

Open a followed Topic normally, refine its query in Search, and open its Follow/Following button. The label continues to describe whether the currently displayed query is followed. The numerical badge on that Search button is gone; the folder-selection count inside Follow and the count on Artist-page Follow pills remain.

A small pencil overlays the top-left corner when the query, profile, or persisted query representation differs from the original Topic. It keeps the button's dimensions and touch target, includes a localized tooltip/accessibility label, remains visible when the new query is followed elsewhere, and disappears on restoration or successful update. The pencil was inspected on Android and retained instead of a dot.

Modified originating Topics have a Save icon in the existing Follow dialog footer, with the same pencil and the tooltip **Update Original Topic**. Ordinary and unchanged searches do not. **Done** applies Follow destinations as before. Exactly one newly created Topic becomes the timeline’s active origin, using its persisted ID, profile, query structure, name, and Auto Update setting. Creating multiple Topics clears the ambiguous origin. With no new Topic, cancellation, failure, or destination removal alone, the existing origin is retained; an existing matching Topic is never chosen arbitrarily. Adoption clears the pencil; subsequent edits update the adopted Topic and leave its predecessor unchanged. **Save** opens a confirmation without applying pending destination changes. Cancelling confirmation preserves those selections.

Confirmation shows the active original Topic name and its complete folder path directly beneath it, full selectable Current Query and New Query, changed profiles, and preservation of name/folder placement. Folder location is resolved by the exact Topic ID from live organization data, supports nested paths, uses Home for an unfiled Topic, and falls back to No folder when placement information is missing. Folder renames/moves update that informational path without changing the immutable edit baseline. The tracking-reset warning and its unused localization key have been removed; the underlying reset behavior is unchanged. Long expressions wrap and scroll. Explicit Update persists; loading blocks repeat actions and dismissal. Errors remain in the confirmation for retry. Success closes both dialogs, shows a toast, keeps Search open, and replaces its original baseline immediately.

The Edit Topic settings dialog now contains only name and Auto Update. The separate Edit Query action, `TopicQueryEdit`, route parameter, route helper, custom restoration branch, and bottom action scaffold were removed after verification of the replacement. The shared Search controller, autocomplete, automatic results, profile selector, and viewer remain.

## State and persistence

- Topic navigation captures an immutable Topic/profile snapshot before editing begins. The existing `TopicSearchOriginScope` remains the single active-identity source, changed only after successful explicit Save or Follow creation. SearchParams and Follow controls use that active ID rather than restoring the initial route’s ID after a profile rebuild. Search owns the baseline outside the engine-specific subtree; it is never re-derived from live Topic data during editing.
- Profile switching preserves active identity (including an adopted or deliberately cleared origin) and the query/input snapshot across engine replacement. Once a Topic has supplied local source ownership, clearing an ambiguous origin does not revert the displayed profile or query. It remains local to Search. Opening/returning from the Post Viewer retains the same controller, profile, baseline, and modification indicator.
- Query comparison normalizes harmless whitespace and checks persisted typed/raw representation. Complete raw expressions stay opaque, and typed tags persist as typed structure.
- The existing controller commits valid pending input, including an edited chip's parked draft. Incomplete supported operators, active IME composition, and empty queries cannot enter the save flow. No second query controller or autocomplete path was added.
- Modal ownership belongs to the stable Search scaffold: committing pending input can replace the result header and must not invalidate an open dialog's context/ref.
- Update reuses `FollowingTopicsNotifier.editLocally()` and repository edit with `expectedTopic`. The stable ID, name, folder placement, creation time, and Auto Update are preserved. Existing duplicate, missing-profile/auth, stale/deleted Topic, atomic rollback, snapshot invalidation, and backup contracts apply.
- Persistence completes before a separate baseline refresh starts. Refresh failure reports a preview warning and never turns a successful write into a failed-save retry. Unsupported tracking does not prevent saving.
- No Hive schema or migration was added.

## Origin-switching and confirmation verification (`7184ef923`)

- The new adoption regression failed on the previous source because the active ID remained the predecessor’s ID after creating a new Topic. It passes after the fix, including a subsequent confirmed update to the new ID with the original Topic unchanged.
- `fvm flutter test --no-pub --concurrency=6 test/core/search/following_topics/update_original_topic_flow_test.dart test/core/search/navigation_search_profile_test.dart`: **35 passed**, 33s. Covers single/multiple/no-op/failed/cancelled creation, removal without creation, ordinary Search adoption, persisted settings copied from another independent match, retained/cleared identity through profile replacement, viewer return, subsequent updates, exact nested folder paths, live folder changes, missing/deleted Topics, and 320 dp/enlarged/keyboard layouts. Assertions verify warning absence.
- `fvm flutter test --no-pub --concurrency=6 test/core/search test/boorus/danbooru_artist_follow_test.dart test/application/topic_query_viewer_return_test.dart test/application/navigation_viewer_lifecycle_test.dart test/application/search_history_flow_test.dart test/application/soft_keyboard_search_flow_test.dart test/application/search_suggestion_category_flow_test.dart test/application/cross_profile_lookup_flow_test.dart test/application/profile_management_context_menu_flow_test.dart`: **898 passed**, 1m46s, exit 0, on the final runtime/test state committed as `7184ef923`.
- Affected-scope FVM analysis: **five existing informational diagnostics; no warnings or errors**, exit 0. Checked the six changed runtime files and both changed test files.
- `./gen.sh i18n`: validation and generation passed after removing `original_reset_warning` from the base locale. No remaining runtime references to that key or the old update callback name.
- Formatting: all eight changed Dart files passed with zero changes. `git diff --check` passed.
- Reviewed the complete follow-up diff and Search/Following consumers. No new persistence path, schema, query controller, dialog redesign, or dedicated editor was introduced. The notifier’s Follow result now reads back the newly persisted Topic after copying sidecar settings, so adoption does not retain an outdated Auto Update value and falsely fail its next stale-edit check.
- The profile fixture now supplies the existing Kurumi theme extension when a completed source response renders posts. Memory-operation tests wait for explicit completion while yielding fake/real async queues, including a mutation queued behind a refresh. No host-speed budget or fixed sleep was introduced.

No unresolved edge cases from the requested matrix remain in the automated coverage. No Android APK rebuild or Maestro run was performed for this scoped follow-up; the device evidence and screenshots below belong to the previous implementation. A fresh Android A → refine → Follow B → viewer/profile round-trip → refine → Update B journey, including nested-folder confirmation, remains unrun for this follow-up. Before integration, the complete suite must pass on the final combination with current develop; the earlier full pass cannot be reused for this changed source.

## Dedicated-editor removal audit

The old dedicated workflow has no runtime references to `TopicQueryEdit`, `topicEdit`, `openTopicQueryEditor`, its custom action scaffold, or the Edit Query localization key. A final audit found an obsolete `_refreshEditedTopic` helper and its material-edit branch in the settings-only dialog’s save adapter. This commit removes both; name and Auto Update saves cannot change query/profile, and stale-edit protection rejects concurrent editable changes.

Shared typed/raw persistence, rollback/stale checks, pending-input validation, and first-input autocomplete fixes remain in active use by ordinary Search and the replacement flow. Historical handoff references and reused test filenames are intentional.

After this removal, the existing settings-dialog, Following-page, and query-persistence suites passed: **83 tests**, 18s, exit 0. FVM analysis of the changed page passed with six existing informational diagnostics and no warnings or errors. Formatting and whitespace checks passed. No new Android run or complete regression pass was performed for this dead-branch removal; the integration gate was pending at that stage; the final approved integration record below supersedes it.

## Previous automated verification (`26657f706`)

- `./gen.sh i18n`: passed validation and generation. Removed the obsolete Edit Query key in both existing locales; new strings use `context.t` with the normal locale fallback.
- Focused workflow/layout/profile checks: **44 passed** before removing the old editor. They exposed and verified fixes for the disposed result-header context and narrow/enlarged footer/confirmation overflow.
- Adapted settings and Following-page tests: **77 passed**. Query/input/profile/retry coverage moved to ordinary Search with real repository writes rather than being discarded.
- `fvm flutter test --no-pub --concurrency=6 test/core/search test/application/topic_query_viewer_return_test.dart test/application/navigation_viewer_lifecycle_test.dart test/application/search_history_flow_test.dart test/application/soft_keyboard_search_flow_test.dart test/application/search_suggestion_category_flow_test.dart`: **876 passed**, 2m07s. Subsequent long-expression test/localization cleanup is included in the complete gate below.
- Final Search/Artist consumer matrix after restricting count removal to Search: **52 passed**, 25s; both affected widgets analyze with no diagnostics. The first complete-gate attempt exposed the Artist semantics regression and was stopped after the confirmed failure; it is not counted as a pass.
- Complete gate on `26657f706`: `./scripts/run_regression_tests.sh` completed with exit 0: **5,193 application tests** (8m34s), **all 13 package/CLI suites** (1,595 passed, two existing GoRouter skips), both PR-policy/Android-release shell suites, and **72 Python tooling tests**. This is the unchanged committed runtime/test/generated-output candidate; this report-only update does not change it.
- Final affected-scope FVM analysis: **30 informational diagnostics, no warnings or errors**. Includes Search, Following, new/adapted workflow tests, engine-switch tests, and the application viewer-return test.
- Changed Dart formatting and staged whitespace checks: passed.
- `fvm flutter build apk --debug --flavor dev`: passed. Existing Android toolchain compatibility warnings remain.

The tests cover ordinary/unchanged Search, modification and restoration, existing matches elsewhere, independent Done and Save, confirmation cancellation and preserved selections, metadata/settings/organization preservation, profile switches and restoration, raw/typed representation, valid pending/parked input, incomplete syntax/composition/empty input, duplicates, storage errors and retries, stale/deleted Topics, missing profiles, repeated presses/loading/Back, refresh failure separation, post round-trips, reopen persistence, and 320 dp/enlarged/keyboard layouts. The real-app regression inspects the retained modified Follow action in the first viewer-return frame before the reverse transition settles.

Critical review covered the complete baseline-to-candidate diff and new files, route ownership, engine rebuilds, save/follow separation, stale checks, rollback, post transitions, and layout/error states. No independent reviewer or subagent was used.

## Historical Android verification on October 27 (`26657f706`)

- Exclusively leased `emulator-5554`, approximately 360 logical pixels wide. Installed with `adb install -r -d`; no app-data reset or account changes.
- Final local/installed APK SHA-256: `8194449ff71b6831073657f2b6d57f1b8c2f6c465d2649b23e34502545dc29fb`.
- Before removing the old editor, verified live automatic results, refinement to `landscape -id:1..1000`, modification semantics, cancellation back to Follow, saving despite a pending Home selection, retained Search, cleared modification indicator, closing/reopening the saved query, profile changes Default → Safebooru → Default, profile comparison details, and actual Post Viewer opening/Back. Safebooru returned no results for that source-specific expression; saving/reopening still retained the selected profile.
- Replacement APK checks before the final Artist-count compatibility fix (APK `b2e32c66f8221bd35b5452a86cc069168a2a2b54bf74ae0709d27222dae53bf7`): After removal, verified name/Auto Update-only settings; another refinement to `landscape -id:1..1000 -id:1001..2000`; Save with a pending Home selection; Cancel back to Follow; explicit Update; preserved `QA60 refine` name and disabled Auto Update; unchanged query/profile after close/reopen; and a cleared modification indicator. Final committed APK smoke: passed 29 Maestro commands on the final committed build, including ordinary Follow creation, hidden Search count, modified Save, persisted query on reopening, and removal of the temporary Topic.
- QA cleanup and lease: Removed only the temporary QA Topic and confirmed `No topics yet`, matching the initial state. Lease release: released after final APK hash verification.

Device failure injection for disk errors, stale/deleted Topics, disappearing profiles, and repeated-write gates remains covered by controlled automated tests rather than Android fault injection. The 320 dp/enlarged/keyboard matrix is automated; emulator accessibility settings were not changed. The ignored historical confirmation screenshot and other local QA images were archived outside the completed task worktree before cleanup.

## Integration boundary

The earlier task-branch checks did not qualify newer develop combinations. The approved integration record below covers the final combination; publication and issue closure follow only after that gate succeeds. The containing squash commit preserves `(#60)` in its Conventional Commit subject.

## Approved develop integration verification

The user approved merge and the normal publication/closure/cleanup workflow. The isolated task worktree was used to prepare one squash commit on `origin/develop` at `c9493298b58db25a3ccaec57fc40adea57fbe808`; the primary checkout and its unrelated `.gitignore` modification remain untouched.

Conflicts preserve develop’s post-based ID refinement (#66) and current UI labels (#50), while keeping the dedicated query/profile editor removed. The Search scaffold retains `PostSearchActionsScope` and the active Topic scope. A new integration regression refines the query from a post and explicitly saves it to the original Topic through Follow. Shared-profile logo assertions use the existing Search selector; test text follows develop’s capitalization. The post-action fixture isolates autocomplete with a deterministic suggestion notifier so its unrelated debounce does not outlive the test.

The merged targeted matrix passed **113 tests** (41s). Search/Following analysis passed with **26 informational diagnostics, no warnings or errors**. Merged i18n validation/generation and formatting passed. Complete combined-candidate regression passed with exit 0 via `./scripts/run_regression_tests.sh`: **5,225 application tests** (7m24s), **all 13 package/CLI suites** (1,597 passed, two existing GoRouter skips), both PR-policy/Android-release shell suites, and **72 Python tooling tests**. The checked candidate was `750657d607d8379ee7e616705a2ff8a4f58d9b2c`; the subsequent amend changes only this handoff, with identical runtime/test/dependency contents. The containing single-parent squash commit is the approved publication candidate. Local QA/configuration and a verified bundle of the completed task history were preserved before worktree cleanup. No new Android run is claimed for this integration.
