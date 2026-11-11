# Selection Manager bottom inset: withdrawn report

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`.
The user explicitly corrected the report during this investigation: the fixed navigation-height gap no longer appears to be a problem. Do not create a new bug, reopen completed work or change layout on the strength of the superseded report.

## Source context

[RawPostGrid](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/listing/src/_internal/raw_post_grid.dart) receives `bottomInset` from its host rather than introducing an unconditional navigation-bar-height constant in the Selection Manager. Its `_SelectionMode` adds that inset only when positive, uses SafeArea when it is zero, bounds the footer height and measures the actual bottom obstruction for `NavigationSelectionBridge`. `_SelectionKeyboardInset` separately measures overlap rather than adding the keyboard inset unconditionally.

This inspection supports retaining the current shared layout; it does not prove every caller or device configuration correct. Related historical work is #67, #89 and #106. A future reproduction should name the exact Browse/Search host, navigation visibility, keyboard state and build, then trace the host's supplied inset before proposing a fix.

No code change or device test was performed. Keep narrow-screen, keyboard-open and navigation hide/reveal checks as regression coverage when changing related layout for another reason.
