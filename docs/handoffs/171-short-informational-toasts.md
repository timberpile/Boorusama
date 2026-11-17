# Shorten Actionless Informational Toasts — Technical Handoff

Issue: [#171](https://github.com/timberpile/Boorusama/issues/171)
Source reviewed: [`develop` at `55cec5ae2b69`](https://github.com/timberpile/Boorusama/tree/55cec5ae2b697612a68af40ed3a8bc4ba1caedbb) (2026-11-17).
Audience: local implementation agent. Code snippets are **unapplied proposals**, not verified patches.

## Evidence

**Prior source inspection:** The **Upvoted** success path uses `KurumiDurations.shortToast` (approximately one second) through `GuardLoginSnackBarX`; **Bookmarked** uses a generic `Kurumi.showSuccessToast` without an explicit duration. Re-check these entry points and the current Kurumi API on the implementation branch; the lifetime difference is user-reported and has not been timed on-device.

## Suggested implementation

Use `KurumiDurations.shortToast` as the default for a *success/informational toast with no action*, preferably at the shared wrapper/dispatcher level. Avoid hand-adjusting many unrelated call sites. The essential change at the relevant call is:

```dart
// Illustrative option on the existing Kurumi success-toast call:
duration: KurumiDurations.shortToast,
```

Only apply the short policy to lightweight confirmation messages: Bookmarked/Unbookmarked and similar actionless success/info notifications. Toasts containing Undo, Retry, instructions, warnings, or errors must retain appropriate longer lifetimes. Beware a global default change if it also governs actionable toasts; split defaults by toast category instead. Preserve replacement/queue semantics.

## Focused verification

- Capture the display duration of Upvoted, Bookmarked and another actionless success: same short lifetime.
- Undo and error toasts remain readable and actionable.
- Rapid successive actions, navigation, accessibility text scaling and bottom-inset positioning still behave correctly.
