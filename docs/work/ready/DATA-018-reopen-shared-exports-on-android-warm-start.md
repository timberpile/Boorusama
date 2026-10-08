# Reopen shared exports on Android warm start

Priority: High  
Affected feature: Android external .bsexport handoff and import review  
Status: Unclaimed

## Problem and reproduction

Opening a `.bsexport` attachment from an Android messenger starts Boorusama and opens import review on a cold start. If Boorusama stays alive and the user returns to the messenger and opens **the same attachment again**, Boorusama comes to the foreground but import review does not open. Repeating an explicit import is a valid user action, not a duplicate notification to discard.

## Expected behavior and acceptance criteria

- [ ] Every distinct user-initiated `ACTION_VIEW` or `ACTION_SEND` of a valid export opens import review, whether Boorusama is cold, already running in the background, or foregrounded.
- [ ] Opening the **same file with identical bytes** twice in one app process opens review twice; opening a different export also works. Dismissing/canceling one review does not suppress a later explicit open.
- [ ] A *single* delivery arriving through both the pending-intent and live-event paths opens review only once. Repeated resumes/foreground transitions without a new external intent do not reopen an old import.
- [ ] Multiple quick external opens are handled deterministically without corrupting or deleting a staged file needed by another pending review. Read permissions, staging cleanup, and failure handling remain safe.
- [ ] Boorusama keeps its own Android task, the messenger keeps its task, closing review returns to normal app UI, and no `content://` URI reaches Flutter routing as a page.
- [ ] Add targeted Android/platform-boundary and Dart tests distinguishing **same content, new delivery** from **one delivery reported twice**. Verify cold and repeated warm opens through a messenger or equivalent real Android `ACTION_VIEW`/`ACTION_SEND` dispatch.

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
