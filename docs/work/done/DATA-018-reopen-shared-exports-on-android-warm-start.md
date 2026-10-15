# Reopen shared exports on Android warm start

Priority: High  
Affected feature: Android external .bsexport handoff and import review  
Status: Done

Agent/session: Codex `/root`
Work branch: `agent/data-018`
Worktree: `/home/timber/code/Boorusama/.worktrees/data-018`

## Problem and reproduction

Opening a `.bsexport` attachment from an Android messenger starts Boorusama and opens import review on a cold start. If Boorusama stays alive and the user returns to the messenger and opens **the same attachment again**, Boorusama comes to the foreground but import review does not open. Repeating an explicit import is a valid user action, not a duplicate notification to discard.

## Expected behavior and acceptance criteria

- [x] Every distinct user-initiated `ACTION_VIEW` or `ACTION_SEND` of a valid export opens import review, whether Boorusama is cold, already running in the background, or foregrounded.
- [x] Opening the **same file with identical bytes** twice in one app process opens review twice; opening a different export also works. Dismissing/canceling one review does not suppress a later explicit open.
- [x] A *single* delivery arriving through both the pending-intent and live-event paths opens review only once. Repeated resumes/foreground transitions without a new external intent do not reopen an old import.
- [x] Multiple quick external opens are handled deterministically without corrupting or deleting a staged file needed by another pending review. Read permissions, staging cleanup, and failure handling remain safe.
- [x] Boorusama keeps its own Android task, the messenger keeps its task, closing review returns to normal app UI, and no `content://` URI reaches Flutter routing as a page.
- [x] Add targeted Android/platform-boundary and Dart tests distinguishing **same content, new delivery** from **one delivery reported twice**. Verify cold and repeated warm opens through a messenger or equivalent real Android `ACTION_VIEW`/`ACTION_SEND` dispatch.

## Technical context and constraints

`MainActivity.onNewIntent()` already forwards incoming intents; do not treat a missing handler as the established cause. In `ReceivedExportChannel.stage()`, the event `id` is currently the file's SHA-256 hash. `ReceivedExportService._receivedIds` suppresses later events with the same ID for the service lifetime. This likely conflates content identity with delivery identity and explains the same-file warm-start failure. Confirm the path before changing it.

Preserve deduplication of repeated *delivery* notifications, but distinguish separate user actions, even when the file content is identical. Inspect the content-hash-based native cache filename and Dart transient-copy cleanup for successive and overlapping deliveries. Avoid broad navigation or share-flow changes.

Relevant code and history:

- [Android receiver](../../../android/app/src/main/kotlin/com/timberpile/boorusama/ExportOpenActivity.kt)
- [MainActivity](../../../android/app/src/main/kotlin/com/timberpile/boorusama/MainActivity.kt)
- [Native received-export channel](../../../android/app/src/main/kotlin/com/timberpile/boorusama/ReceivedExportChannel.kt)
- [Dart received-export service](../../../lib/core/backups/export_import/platform/received_export_service.dart)
- [Import navigation listener](../../../lib/core/backups/export_import/platform/received_export_listener.dart)
- [Existing delivery deduplication test](../../../test/core/backups/export_import/received_export_service_test.dart)
- [DATA-007: Android task separation](../done/DATA-007-open-exports-in-own-android-task.md)

Dependencies: None. Preserve the completed DATA-007 behavior. The in-progress outbound [unified sharing item](../in-progress/IDEA-029-unified-share-flow.md) is adjacent but not a prerequisite.

## Decision

2026-10-08: Repeatedly opening an export from a messenger must work on warm start, including when the file is unchanged. GIF thumbnail optimization is not part of this task.

## Implementation and verification

Confirmed that `onNewIntent` already reaches the receiver. The defect was the
SHA-256 delivery ID and cache path: Dart remembered that ID for the service
lifetime, suppressing subsequent explicit opens of unchanged content.

Android now stages each receive with a fresh UUID and an independent cache file.
The same staged delivery retains its ID across channel notifications, preserving
Dart deduplication. Queued reviews retain independent private copies. The native
staging helper preserves bounded streaming, closes provider streams, and removes
partial files on failure. Receiver task flags and navigation remain unchanged.

Local focused verification: 12 Flutter tests passed; three native JVM staging
tests passed; affected Dart analysis passed. Regressions cover identical bytes
with new IDs, a single delivery on both pending/live paths (including the same
source path), opening again after dismissal, deleting one queued input without
affecting another, oversized input, and provider read failure followed by success.

The implementation passed the complete local application suite (3,009 tests),
all 12 package suites including the CLI, repository-tooling checks, 33 Gradle
native unit tests, focused Dart analysis, and a Dev debug APK build. The complete
local suite is rerun on the combined current `develop` tree before integration.

## Manual acceptance and completion

2026-10-10: The user initially reported that Signal still opened review only on
the first attempt after switching to `agent/data-018` and hot reloading. Hot
reload did not load the changed Kotlin/Java receiver. After stopping the Flutter
session and rebuilding/reinstalling the native app, the user confirmed that the
same export now reopens correctly from Signal and authorized merging.

The user's Signal check verifies the original repeated-open failure end to end.
Pending/live deduplication, independent queued inputs, and staging failure
cleanup are covered by focused Dart/native regressions. Android task flags and
routing are unchanged from DATA-007. No new automated Android UI sweep or
upgrade test was performed: Maestro discovery remained unavailable. No agent
operations were performed on the user's phone.
