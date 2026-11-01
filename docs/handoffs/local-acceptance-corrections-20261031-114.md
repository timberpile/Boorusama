# Local acceptance corrections — Issue #114

## Scope and commits

Branch: `feature/114-timeline-toolbar`. Initial commit: `152aecac4d5f68bc122cec3006ddd6f8f9fe786e`. Final runtime/test candidate: `121c619b2518c82ddfd4d1b53f2ad57ca1388fd1`. This report is a subsequent documentation-only commit; its final HEAD is listed in the aggregate handoff. The complete regression below checked this exact candidate; report-only updates do not change it.

Local corrections only. No push, merge, PR, issue closure or branch deletion was authorized or performed.

## Changes and diagnosis

Flutter's floating toolbar received positive preceding AppBar overlap but painted at origin zero, behind the Search AppBar. A narrow render-proxy sliver now accounts for that overlap and reduces its available paint extent. Scroll extent, direction handling, transparent toolbar styling, blacklist controls and the pinning preference remain intact.

The added production application journey uses 120 real grid posts, scrolls more than 1800 px and reverses 40 px repeatedly at 320 dp and 1x/2x text, with pinning on/off. It verifies controls below the Search AppBar and unchanged raw post identities.

## Executed checks

- `fvm flutter test --no-pub --concurrency=6 test/application/timeline_toolbar_scroll_flow_test.dart test/core/posts/listing/timeline_header_sliver_test.dart test/core/posts/listing/timeline_toolbar_widget_test.dart test/core/settings/timeline_toolbar_settings_test.dart` — PASS; evidence `114-focused.log/.json`.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/posts/listing/src/widgets/timeline_header_sliver.dart test/application/timeline_toolbar_scroll_flow_test.dart` — PASS; evidence `114-analysis.log/.json`.
- `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS; evidence `114-fixed-build.log/.json`.
- `./scripts/run_regression_tests.sh` — PASS; evidence `114-full.log/.json`.

The complete runner includes application tests, every tested package/CLI and repository tooling. Default concurrency was 6 physical cores. Scoped analysis: 0 errors, 0 warnings, 4 informational findings (details in its log). The exact build command and source state are recorded above. No old handoff pass is substituted for this candidate.

## Device evidence and remaining acceptance

The original normal APK reproduced the reported missing toolbar on a populated application timeline. The corrected normal APK revealed it after a small upward movement. Emulator5554, no app-data reset. APK build/source state is recorded in114-fixed-build.json; the runtime/test commit was created during that build without changing its source content.

Manual review: scroll a long Browse/Search timeline down, reverse slightly repeatedly, switch Keep Timeline Toolbar Visible on/off, and inspect blacklist actions and transparent styling. Refresh/error behavior is covered by existing automated regressions.

## Integration and evidence limits

This branch owns the shared floating-header correction. #107/#117/#118 contain the identical TimelineHeaderSliver source from121c619b; integrate the common implementation once and resolve any branch-history conflicts deliberately. Individual branch verification does not verify a future combined develop candidate. That candidate needs the complete integration gate after any runtime/test/dependency changes.

Durable local logs, JSON provenance and private device evidence: `/home/timber/code/Boorusama/.worktrees/_artifacts/local-acceptance-corrections-20261031/`. Important development files were retained outside `/tmp`. GitHub claim metadata stayed local after automatic approval review rejected the attempted persistent issue comment under this local-only task; no comment was posted.

## Additional acceptance correction

The toolbar now uses the existing overflow button's dark translucent overlay color across its entire width and measured height. The overflow button is transparent when inside that shared header, avoiding a second dark layer; popup contents retain their existing styling. This replaces the earlier fully transparent-surface acceptance requirement. Floating/pinned scrolling, empty/error recovery and enlarged geometry are preserved. Final focused tests passed; complete regression is recorded in the follow-up report.

## Accepted layout refinement — 2026-11-01

Halve the standard timeline toolbar outer vertical spacing from 4 to 2 logical pixels per side. Keep the 48 dp minimum control region, fixed overflow and horizontal scrolling. The shared layout accepts an explicit vertical-padding override for the Feed consumer. Focused timeline/scroll suite: 13 passed; scoped analysis: no findings.

The aggregate `acceptance-layout-20261101` handoff records exact final commits and verification results. Previous complete passes predate these layout refinements. Changes remain local for review; no integration is authorized for this branch.
