# Issue #66 — Modify Search from Posts

## Branch and agreed behavior

- Branch: `feature/66-modify-search-from-posts`.
- Independent base: `88536ed64b0f8ea7eb0b7a225321ce6fe2ccd887`.
- This follow-up continues `5d9f2122cba8cad62600fe167b3ed21c0dd93ca3` and supersedes the original grid/Viewer entry points with the user's Selection Manager-only requirement.
- **Modify Search** is available exclusively in the Selection Manager for exactly one post from a compatible active search/profile. It is absent from grid context menus and the Post Viewer.
- The Kurumi popup contains only **This Post and Newer** and **This Post and Older**, without a duplicate heading. German: **Dieser und neuere Beiträge** / **Dieser und ältere Beiträge**.
- Both actions include the selected post (`id:>=…` / `id:<=…`). Success clears selection and keeps the current search open.

## Implementation and safety

The live `SearchPageScaffold` still owns profile-bound query refinement. Existing standalone ID limits are replaced; other tags and ordering are retained. Saved Following Topics and their tracking state remain unchanged. Unsupported sources, ambiguous nested ID clauses, pending query edits, profile changes and invalid post IDs fail closed.

Removed the obsolete grid submenu, Viewer action and ephemeral Viewer route capability. This also removes the extra Viewer `watchConfig` dependency introduced by the old entry point. The selection action reuses the existing multi-selection popup component and reports failed refinements without clearing selection.

## Verification — 2026-10-26

The following checks apply to the Selection Manager-only implementation at `52d01705b`, on top of `5d9f2122c`.

- FVM format: all nine changed Dart files unchanged by the final format check.
- Localization: `./gen.sh i18n` completed after updating English/German resources.
- Affected application and consumer regression: **83 tests passed**, concurrency **6**:

  ```sh
  fvm flutter test --no-pub --concurrency=6 \
    test/application/selection_search_actions_flow_test.dart \
    test/application/post_selection_flow_test.dart \
    test/application/post_selection_layout_flow_test.dart \
    test/application/unified_post_actions_flow_test.dart \
    test/application/selection_feedback_flow_test.dart \
    test/core/posts/post_viewer_original_actions_test.dart \
    test/core/posts/details/mixed_post_details_page_test.dart \
    test/core/posts/details/post_presentation_context_test.dart \
    test/core/search/post_search_actions_test.dart \
    test/core/search/post_id_search_filter_test.dart
  ```

- New application flows exercise both inclusive directions, absence from context menu/Viewer, one-versus-multiple selection, and absence outside an active search. The older-post flow also exercises a 320 px phone, 2x text and an open keyboard, checking that its popup choice stays within the visible width/height.
- Focused FVM analysis of affected source/routes and the new flow tests: **no issues found**.
- `git diff --check` and both translation JSON syntax checks passed.

## Two-line action label follow-up

The follow-up on top of `52d01705b` enables a maximum of two caption lines for **Modify Search**. The existing single-line caption and spacing budget is reused so button dimensions and icon coordinates remain unchanged. Words stay intact before the caption scales down if needed to fit that budget. Other action buttons retain their existing label layout.

- Final runtime state in the commit containing this handoff: **17 affected tests passed**, concurrency **6**:

  ```sh
  fvm flutter test --no-pub --concurrency=6 \
    test/core/widgets/multi_selection_action_bar_test.dart \
    test/application/selection_search_actions_flow_test.dart \
    test/application/post_selection_layout_flow_test.dart
  ```

- Geometry tests compare button rectangles and search/neighbor icon positions before and after wrapping, using a 320 px five-button row, English/German captions and 1x/2x text. They also verify complete captions, actual line wrapping, label containment and popup interaction.
- Search flows retain their narrow-width, enlarged-text and open-keyboard coverage.
- FVM formatting, focused analysis (**no issues found**) and `git diff --check` passed. No new emulator or full-suite run was needed for this scoped opt-in layout change; the integration limits below still apply.

## Acceptance and final integration — 2026-10-27

The user accepted `10e7a457710e1e4b3e6b84bc016deb0fdbb0e764` and authorized its merge, publication, issue closure and completed-branch cleanup. The final candidate combines that approved branch with `origin/develop` at `6d7e988fde16c2b3187afad41614cf1197591a6b`. Git merged it without conflicts. Before this report-only update, its tree was `eb523f507484a9596b274b18e9d2e341def47030`, matching `git merge-tree` exactly.

The scoped verification sections above describe earlier source states. Final integration verification is recorded below. No additional APK build, emulator/Maestro or live-site check was performed during integration; the application flows use a fake backend and the user supplied final UI acceptance. No Astra review was requested or run.

Final combined-candidate checks:

- `./init.sh`: pinned FVM setup, dependency resolution and required generation completed.
- `./scripts/run_regression_tests.sh`, default concurrency **6**: **5,169 application tests**, **1,595 package/CLI tests across all 13 package suites**, both repository shell suites and **72 Python tests passed**. Two pre-existing disabled `go_router` tests were skipped (`routing_config_test.dart:142` and `go_router_test.dart:4743`); no suite was omitted. The earlier asynchronous cache-settings failure and four Viewer failures do not reproduce in this complete pass.
- `fvm flutter analyze --no-pub --no-fatal-infos`: exit 0, **0 errors, 0 warnings, 3,164 informational diagnostics**.
- `git diff --check` passed. The final runtime/test/dependency tree remains identical to the tested merge result; only this report changed afterward.

The approved task is delivered as one Conventional Commit on `develop` with `Closes #66`. Publication is verified before issue closure and deletion of the completed remote/local task branch and worktree. The primary checkout and unrelated task branches remain untouched.
