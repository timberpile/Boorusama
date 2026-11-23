# #170 Following Topic added-date sort verification

Base: `4542aaa44e5002f7d546fb4ec96bf4cb0523cee5` (original develop base, includes #144).
Follow-up source: task changes based on `49dd651d3`, included in the commit containing this report.
Branch: `feature/170-following-topics-added-sort`. Refs #170; integration and Android acceptance pending.

## Behavior

The topic-list menu contains exactly **Manual**, **Name**, **Unread First**, and
**Recently Added**, in that order. Recently Added uses persisted
`FollowingTopic.createdAt`, newest first, then position and ID. The four retained
settings identifiers are unchanged. Removed values `addedOldest` and
`lastPostOldest` fall back to Manual in settings decoding and the enum parser.

Manual inputs and Recently Added folder ordering remain unchanged; received-folder
controls remain read-only. No timestamp migration is required. The three
Following Topics sort labels are localized in all 23 locales; Name reuses the
existing localized short label. Separate feed-member sort controls are unchanged.
The menu retains its existing Kurumi popup, rows, and selection check.

## Local verification

- `./gen.sh i18n`: translation validation and both translation/language generation passed.
  The i18n package has no test directory; its complete source was included in analysis.
- Formatted all ten changed Dart files with `fvm dart format`.
- `fvm flutter test --no-pub --concurrency=6 --reporter expanded test/core/search/following_topics test/core/settings`:
  **854 tests passed**. This includes topic and feed-member behavior, folder actions,
  settings consumers, final filtered/received projections, and the four-option menu
  at 320px / 200% text with and without an open keyboard.
- Final focused rerun with the same flags on `following_topic_added_sort_test.dart`,
  `following_topic_sort_test.dart`, `following_topic_sort_persistence_test.dart`,
  and `following_topic_final_projection_sort_test.dart` in that Following Topics
  directory: **24 tests passed**. Covers creation-date ties, unchanged manual inputs,
  removed-setting fallbacks, persistence, and final display projections.
- `fvm dart analyze` on the ten changed Dart files and `packages/i18n`:
  **zero errors, zero warnings, 26 informational findings**, all on unchanged lines.
  An initial analysis caught a missing test import; it was corrected before the
  successful analysis and final focused test run.
- `git diff --check` passed. Locale comparison confirmed only the three relevant
  sort labels and obsolete keys changed.

Durable logs: `.worktrees/_artifacts/170-sort-options-20261117/` in the primary workspace.

## Remaining acceptance

Not performed: Android/device/emulator checks, actual restart/import/MiteMite
integration, live services, APK builds, or the complete repository regression
suite. Verify Android sorting, folder navigation, restore, and read-only received
folders before accepting their device behavior. This remains an independent
feature excluded from the bugfix preview. Develop integration requires its
complete-suite gate and separate publication authorization.
