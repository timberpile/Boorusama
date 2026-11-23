# Issue #116 — compact Follow button local completion

[Current all-branch review](116-all-live-review-2026-10-30.md) supersedes the technical-readiness status below; this record retains its original evidence.

Continue `feature/116-compact-follow-button`, independently based on develop
`422aeae087c1108e655d85d1a3dac25120456cd6`. Read current AGENTS.md and the issue
before claiming the branch in an isolated worktree. No #114/#115 code is included.

## Implemented source

The compact presentation uses a 36-pixel minimum painted height and 10-pixel
horizontal padding. Explicit standard visual density and a padded tap target
retain at least 48 logical pixels for input. Both Follow and Following reuse
the same style. The busy icon occupies the same 20-pixel slot as the RSS icon.
Larger text may naturally increase the painted height; no fixed-height clipping
was introduced. Non-compact styling, radii, labels, counts, modification badge,
state mutations and follow dialogs remain unchanged.

## Verification and remaining work

- The original source was checked against its Git blob SHA before patching.
- Reviewed the scoped diff and ran `git diff --check` and UTF-8/newline checks.
- Prepared `test/core/search/following_topics/compact_follow_pill_test.dart`
  for the minimum visual size, actual padded-edge tap, state-stable height,
  320-pixel enlarged-text layout, and unchanged non-compact presentation.
- FVM/Flutter/Dart are unavailable. The focused FVM test command fails to start
  with exit 127. No Dart format/analyze/test, build or device checks have passed.

Run with the pinned FVM SDK:

```bash
fvm dart format lib/core/search/following_topics/src/widgets/topic_follow_control.dart \
  test/core/search/following_topics/compact_follow_pill_test.dart
fvm flutter test --no-pub test/core/search/following_topics/compact_follow_pill_test.dart
fvm flutter test --no-pub test/core/search/following_topics/search_page_follow_action_test.dart
```

Analyze the affected scope and test neighboring follow controls. Review hit
regions/semantics through the Material UI compatibility bridge, not merely the
style object. On Android compare the old/new compact fill, Follow/Following,
busy and modified states at 320/390 dp and large text. Confirm that the unchanged
modification badge remains visually attached to the smaller fill and does not
clip. No final dimension or device-quality claim is made remotely.

Coordinate later visual acceptance with #114/#115, but do not pull their
unmerged implementations into this branch. Before integration run the complete
regression suite on the final candidate. Prepare a development build for Timber
and report exact commit, commands and limitations. Do not merge, open a PR,
close the issue or publish a release without separate authorization.
