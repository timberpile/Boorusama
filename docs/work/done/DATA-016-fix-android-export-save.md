# DATA-016: Fix Android export Save file

Priority: Normal
Affected feature: Export save destination on Android

## Problem

Save opens folder selection and permission confirmation, then returns to the
export screen without writing a file for some destinations. Documents works;
Share file works. Investigate actual Android storage access and error handling.

## Acceptance criteria

- [x] Reproduce the failing save path and identify its cause before changing it.
- [x] Save a valid export to a user-selected supported destination on Android.
- [x] Handle unavailable destinations/write failures visibly; cancellation remains quiet.
- [x] Preserve working Documents save, sharing, filename collision behavior and export contents.
- [x] Add meaningful regression coverage and verify Android behavior when feasible.

## Claim

- Coordinator: /root, 2026-10-06 android-export-save
- Implementer: /root/android_export_save
- Branch: fix/android-export-save
- Worktree: /home/timber/code/Boorusama/.worktrees/android-export-save
- Base: current local develop, be6fe19f3

Read development workflow, engineering guidelines, unified export/import design
and related DATA-001/DATA-008 tickets. Scope: export destination writing and
necessary platform/error feedback. No unrelated storage permission expansion.
Integration and publication require separate approval.

## Completion evidence

- Reproduced on emulator-5558, Android API 36: choosing
  `Pictures/BoorusamaExportQA20261006` and allowing access returned without a
  file. Logcat showed an unhandled raw-path `PathAccessException` (errno 1).
  Baseline Documents save worked. The folder picker discarded its granted URI;
  its synchronous callback also failed to await the asynchronous copy/error.
- Android Save now retains the transient read/write document-tree URI, creates
  a new document through `DocumentsContract`, and streams the existing export
  through `ContentResolver` in 64 KiB chunks. Success follows output close;
  failed writes remove their newly created partial document when the provider
  permits cleanup. Errors are localized and cancellation remains quiet.
  Directory picker callbacks now await asynchronous writes. No expanded storage
  permissions or destination whitelist.
- Native source validation accepts only canonical app `cacheDir` and
  `codeCacheDir` roots. The first device candidate exposed Flutter's use of
  `code_cache` for `Directory.systemTemp`; a regression reproduced its rejection
  before the explicit second trusted root was added.
- Corrected Dev APK: Pictures and Documents each saved a 674-byte export with
  SHA256 identical to its generated source. Share displayed the correct dated
  `.bsexport` basename. Picker Back created no additional file. Owned test files
  and folders were removed, absence verified, and emulator lease released.
  [Coordinator Android report](/tmp/android-export-save-20261006-qa.md).
- The two original asynchronous picker regressions were RED, then GREEN.
  All 26 focused Flutter checks passed, including actual error/success/quiet
  cancellation feedback. Eight native JVM checks passed for byte integrity,
  bounded streaming, both cache roots, numbered collisions, failure cleanup,
  and rejected outside sources. Changed production Dart analysis found no
  issues, the corrected Dev x64 APK built, and independent review approved.
  Coordinator independently repeated eight picker/service/feedback tests.
- Complete Flutter suite: 2,614 passed and one share-copy toast test failed
  (`copying Original prepares the exact image and reports success`, expected
  “Copied” was absent). Its isolated named repeat passed. This is reported
  separately from the passing focused checks. Logs:
  `/tmp/android-export-save-20261006/android-export-save-full.log` and
  `/tmp/android-export-save-20261006/android-export-save-repeat.log`.

## Verification limits

The export form reset to initial selection after Save and Share on the emulator
with a stable process PID. This separate observed UI behavior was not changed;
its baseline origin was not established. It prevented repeating the same ready
export for a live collision check. Exact numbered collision behavior is covered
by native regression tests rather than a live repeated-save claim. Device export
integrity was verified through on-device metadata/checksums without copying or
printing payload contents.
