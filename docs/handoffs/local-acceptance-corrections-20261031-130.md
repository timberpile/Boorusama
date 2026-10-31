# Local acceptance corrections — Issue #130

## Scope and commits

Branch: `feature/130-adaptive-titles`. Initial: `ea3961353c5615e1378b98cfe4a327b69c56f977`. Final runtime/test candidate: `064c583657c73c241dfe83d9617251fc926224db`. The aggregate report lists the later documentation-only HEAD. No push, merge, PR, closure or branch deletion.

The requested title redesign was already present. Targeted acceptance found one concrete accessibility defect: the Posts Per Page custom dialog's fixed action Row overflowed by 49px at 320dp and doubled text. This reproduced with the real app/theme, not only a component fixture. The actions now use the same end-aligned wrapping pattern as Follow Topic, preserving wording, submission, validation and Cancel.

## Targeted acceptance

Follow Topic, Manage Topic and Edit Favorite were exercised in a 320dp / 2x / keyboard fixture. Rename and Merge sheets were also inspected through real widgets. The final production-app tests cover the custom Posts dialog and Filter by Label / Rename / Merge sheets, asserting fitting title bounds, usable Cancel, no render exceptions and unchanged tag data. The label test opens its menu at normal scale, then applies doubled text and keyboard to the actual sheet; this avoids mistaking popup positioning for title fitting. Shared Kurumi tests cover long Settings-card, Info and Warning headings, sheet actions, searchable options and popup headings in both themes at 320dp / 2x / keyboard.

Initial exploratory fixture failures (wrong Material Dialog finder, missing provider setup, offscreen popup taps) were not application regressions and were retained in durable logs. Their corresponding final production cases are included, not removed or silently counted as passing. Automatic approval review rejected an earlier proposed test reorganization over coverage concerns; the safer result retained all named surface coverage and corrected navigation setup.

The only runtime source change is the confirmed Posts action overflow fix. No title wording, AppBar, Bookmark batch dialog or broader UI redesign was changed.

## Checks

- `fvm flutter test --no-pub /home/timber/code/Boorusama/.worktrees/_artifacts/local-acceptance-corrections-20261031/130_production_posts_test.dart` — EXPECTED BASELINE FAILURE (49px overflow); `130-production-repro.log/.json`.
- `fvm flutter test --no-pub --concurrency=6 test/application/adaptive_titles_acceptance_test.dart test/application/adaptive_label_titles_acceptance_test.dart test/settings/posts_per_page_presets_test.dart test/core/search/following_topics/follow_topic_dialog_test.dart test/core/bookmarks/bookmark_group_name_dialog_test.dart` — PASS; `130-final-focused-v2.log/.json`.
- `fvm flutter test --no-pub --concurrency=6 test/adaptive_title_hosts_test.dart` — PASS; `130-shared-final.log/.json`.
- `fvm flutter analyze --no-pub lib/core/settings/src/pages/appearance/posts_per_page_dialog.dart test/application/adaptive_titles_acceptance_test.dart test/application/adaptive_label_titles_acceptance_test.dart packages/kurumi/test/adaptive_title_hosts_test.dart` — PASS; `130-analysis-final.log/.json`.
- `fvm flutter build apk --debug --flavor dev --no-pub` — PASS; `130-build.log/.json`.
- `./scripts/run_regression_tests.sh` — PASS; `130-full.log/.json`.

Scoped analysis: 0 errors, 0 warnings, 0 informational findings. Final focused application/nearby checks:22 passed; shared bounded-title checks:12 passed. The complete runner passed the final candidate, including all application/package/CLI/tooling tests. The APK build passed on that same clean commit; no device claim is inferred from the build. Narrow/enlarged-title acceptance used production/widget rendering; no emulator font-scale or account settings were changed for this branch.

## Remaining review and evidence

Review translated long titles, 320dp / doubled text with a keyboard, Posts custom validation/OK/Cancel, Filter search, Edit Favorite save/cancel, Rename/Merge cancellation and Settings/Info/Warning headings. Confirm that titles fit without changing their wording or shrinking ordinary content.

A future combined develop candidate requires its own complete gate after runtime/test/dependency changes. There is no new dependency on #114. Logs and private artifacts are durable under `/home/timber/code/Boorusama/.worktrees/_artifacts/local-acceptance-corrections-20261031/`, outside `/tmp`.
