# Search result header action row

Priority: Normal
Affected feature: Search results
Branch: `fix/search-result-header-actions`
Agent/session: `/root/implement_21`, 2026-10-02
Base: `46558a4d0`

## Problem

Danbooru supplies its endpoint result count as a separate engine header, above
the shared Pin Search and Follow header. Nested unbounded rows and the fixed
count height also prevent the header from adapting to narrow widths and large text.

## Expected behavior and acceptance

- Result count, Pin Search, and Follow occupy the same responsive header row.
- Available actions and their enabled/disabled states remain correct for blank
  queries, unsupported profiles, pinned searches, and followed searches.
- Narrow widths and 2x text render without overflow; count text can wrap.
- Focused widget coverage and Android Maestro inspection verify the layout.

## Context and dependencies

Follow `AGENTS.md`, `docs/development_workflow.md`, and `docs/work/README.md`.
Assigned worktree only; emulator-5556 only. No remote delivery or shared account
mutations. No dependencies.

## Progress

- Inspected shared and Danbooru result header construction and related count widgets.
- Fresh worktree CLI dependency setup and `./gen.sh` completed.
- RED: four layout cases fail because endpoint count is absent from the shared
  header; the 240px case also overflows. Log: `/tmp/boorusama-ready-21-red.log`.
- Consolidated capability-selected result counts into the shared header, removed
  Danbooru's separate count sliver, and bounded/wrapped count and Follow content.
- Initial GREEN: all 15 focused tests passed, including 240px at 2x text.
- Analyzer: exactly 227 info findings, matching the baseline; no touched-file
  findings. Log: `/tmp/boorusama-ready-21-analyze.log`.
- Baseline Android reproduction on emulator-5556: `1 Result` bounds
  `[42,467][256,541]`, Pin Search `[0,557][126,683]`, and Follow
  `[126,557][377,683]` demonstrate separate rows.
- Second RED reproduced the unsupported-Pin feedback widening the action column
  and moving its icon away from count/Follow; feedback now wraps below the row.
  Log: `/tmp/boorusama-ready-21-feedback-red.log`.
- Expanded GREEN: 25 search-header/pin tests and 3 feed-membership tests passed.
  Coverage includes endpoint/search counts, 1x/2x text at 800/320/240px, count
  loading/empty/unavailable/failure, saved/followed management, blank queries,
  disabled unsupported Follow, and aligned inline feedback. Existing async
  dialog checks use a real async turn and bounded animation pumping.
- Final analyzer still reports the baseline 227 info findings and no warnings,
  errors, or touched-file findings.
- Existing unrelated `PostListConfigurationHeader` overflows at 2x text; layout
  tests disable that optional header to isolate the requested result header.
- Full suite passed all 1,498 tests with two workers in 2m22s, exit 0.
  Log: `/tmp/boorusama-ready-21-full.log`.
- Dev APK build passed, exit 0, in 157.9s; installed with `adb -s emulator-5556
  install -r` to preserve app data. Log: `/tmp/boorusama-ready-21-build.log`.
- Maestro on the changed APK verified normal-width bounds: count
  `[42,478][256,551]`, Pin Search `[703,452][829,578]`, and Follow
  `[829,452][1080,578]`. Vertical centers differ by at most 0.5px, both actions
  are enabled/clickable, and their dialogs open and cancel without saving.
- Maestro at 320dp width (`wm density 540`) with system font scale 2.0 verified
  count `[54,594][479,891]`, Pin Search `[546,662][708,824]`, and Follow
  `[708,662][1080,824]`. Count text wraps, all three remain aligned within 0.5px,
  bounds do not overlap or exceed the screen, and actions remain enabled/clickable.
  Screenshots confirmed complete count/Follow text and no header overflow.
- Restored system font scale 1.0 and physical density 420; emulator-5564,
  credentials, and shared account state were untouched.
- `git diff --check` passed. All scoped acceptance criteria are verified;
  independent review and delivery remain with the coordinator.
