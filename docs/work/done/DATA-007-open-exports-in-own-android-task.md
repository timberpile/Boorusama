# Open shared exports in Boorusama's Android task

Priority: High

Affected feature: `feature/backup-sharing-mockup`

Agent/session: Codex `/root`

Work branch: `feature/backup-sharing-mockup`

## Problem

Opening a `.bsexport` from a messenger puts Boorusama in the messenger task.
Flutter also routes the `content://` document URI, briefly showing and later
revealing a Page Not Found screen behind import review. The route error was
reproduced on emulator-5554 with a valid test export.

## Expected behavior

External export opens bring Boorusama's own task forward, preserve the source
app's chat/task, and show import review over a normal Boorusama page. Closing
review never reveals the document URI as a route. Existing custom-scheme links
and `singleTop` billing behavior remain intact.

## Acceptance criteria

- [x] Cold and warm external `ACTION_VIEW` and `ACTION_SEND` export opens reach
      import review without a `content://` router error.
- [x] The import belongs to Boorusama's task while the source app remains in
      its original task and state.
- [x] Closing review shows normal Boorusama UI; unrelated deep links and
      `singleTop` remain unchanged.
- [x] Regression tests, Android build, emulator UI checks, and Flutter suite
      pass.

## Progress and handover

The receiver owns the custom-MIME filters and forwards readable content URIs
to `MainActivity` with a separate app task and no route data. `MainActivity`
keeps `singleTop` and the `boorusama:` link filter. The Android Dev x64 APK built
and was installed on emulator-5554. Cold and warm `ACTION_VIEW` and
`ACTION_SEND` opened import review; closing review returned to normal app UI.
Android task inspection showed one `MainActivity` in a Boorusama-affinity task
and no retained receiver. The focused regression test, targeted Dart analysis,
and the full 1,938-test Flutter suite passed. A first parallel suite run had
one transient unrelated download-session failure that passed in isolation; a
serial full-suite rerun passed.

On 2026-10-03, the user confirmed that opening from a messenger keeps the chat
in place and opens Boorusama independently as expected. The full 1,938-test
suite passed again against the unchanged implementation before completion.

An independent pre-PR review found that `ClipData.newUri` queried untrusted
providers before the import channel could handle read failures. A contacts URI
without a grant reproduced a `SecurityException` crash on emulator-5554. The
receiver now uses raw URI ClipData and catches invalid or ungranted handoffs.
The same URI no longer crashes for either `ACTION_VIEW` or `ACTION_SEND`;
valid exports still reach review and return to normal app UI. The rebuilt Dev
APK passed those emulator checks.

## Dependencies

Existing `.bsexport` direct-open bridge on this branch.
