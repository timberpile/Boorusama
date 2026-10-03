# Use consistent export filenames

Priority: Normal

Affected feature: `feature/backup-sharing-mockup`

Agent/session: Codex `/root`

Work branch: `feature/backup-sharing-mockup`

## Problem

Saved exports use a UTC timestamp, directly shared files use a fixed name,
and automatic exports use a numeric `backup` name despite the unified
`.bsexport` format.

## Expected behavior

User-visible export files use `boorusama-YYYY-MM-DD_HH-mm-ssZ.bsexport`.
The name contains no selected content or template names. Saving or automatic
exporting to a directory with an existing name adds `-2`, `-3`, and so on
instead of overwriting it.

## Acceptance criteria

- [x] Save and direct Share use the same generated basename.
- [x] Automatic exports and Nearby download headers use the same pattern.
- [x] Existing filename collisions receive the next available numbered suffix.
- [x] Focused tests, the full Flutter suite, and Android export UI validation
      pass.

## Completion evidence

The filename helper is shared by manual, automatic, and Nearby exports.
Exclusive destination creation prevents concurrent saves from overwriting
files, and automatic exports are serialized within the app process. Focused
tests cover UTC formatting, collisions, overlapping saves and automatic
exports, and the Nearby response header. Targeted Dart analysis found no
issues; the full 1,944-test Flutter suite passed. The Dev x64 APK built and
on emulator-5554 the Share sheet showed the dated filename; saving it twice
created the base and `-2` files. The three credential-bearing test exports
created during these checks were removed and their absence verified. An
independent read-only review found no remaining actionable issue.

## Dependencies

The unified `.bsexport` export flow on this branch.
