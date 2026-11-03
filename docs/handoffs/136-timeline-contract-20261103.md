# Issue #136: Timeline contract supplement

Later clarification: [approved UI conventions](136-approved-ui-conventions-20261103.md)
keeps search fields rounded and reconciles AGENTS.md with #145. Transparent-input
captures below remain historical evidence, not the current target.

Local branch: `feature/136-kurumi-ui-design-system`, continuing `e0c3306c9`.
Documentation and reviewed screenshot evidence only. Runtime source, the original
30 captures and their Penpot imports remain unchanged. The broader #136 baseline
still requires owner acceptance. No push, PR, merge or issue closure.

Guide/evidence commit: `23c395c2800802a5d147648eaa0755c98300096b`.
The following handoff commit changes documentation only.

## Contract and ownership

Extended `docs/ui_style_guide.md`, without introducing a parallel guide. Defined
Header, Search Bar and Timeline Toolbar without renaming APIs. Recorded opaque
semantic surface ownership, transparent children, downward-hide/slight-upward-
reveal behavior, independent visibility preferences, non-overlap and single
inset ownership. Standard timeline status bars stay opaque/visible; gesture
navigation may remain transparent, three-button navigation needs a consistent
backdrop, and immersive media is an exception. Only #107's translucent-surface
choice is superseded; its other behavior remains unchanged.

Reinforced Kurumi surfaces and presentation-independent picker content. Recorded
the verified custom-child `KurumiPopupMenuButton` InkWell radius gap. #105 owns
evaluation of existing 8 dp and matching rest/press/hover/focus geometry; preserve
circular icon-only controls. No new radius scale or runtime fix was added.

Duplicate checks covered open/closed issues including #98/#107/#114 and
application-navigation issues #67/#85/#89. Deferred runtime work is now tracked:

- [#146: Fix Browse Search Toolbar Overlap](https://github.com/timberpile/Boorusama/issues/146).
- [#147: Unify Android Timeline System Bars](https://github.com/timberpile/Boorusama/issues/147).
- [#148: Standardize Timeline Header Scrolling](https://github.com/timberpile/Boorusama/issues/148).

#107's surface bullet was updated; #105 has the source finding and ownership
clarification. No runtime worktree was created for #146–#148: the user explicitly
requested issues and style guide only.

## Evidence and verification

Added ten reviewed, hashed captures in `docs/designs/136-timeline-evidence/`,
linked from the guide. They supplement the existing 30-image/Penpot set without
replacing its boards. The manifest distinguishes prior #145 baseline from
corrected #139 runtime `eb315fd69`, APK correspondence, applied Light/Dark/Midnight
and dynamic-color states, 360×800 logical viewport, Android 17 gesture navigation,
enlarged text and actual soft keyboard. Collection top/down/reveal captures show
existing transparency/system-bar drift, not acceptance of the new contract.

Missing capture-matrix cells remain unverified: all comparable routes, independent
visibility settings, bottom-search/chip/selection combinations, three-button
navigation, device RTL, physical devices and assistive input. The old set retains
its separate provenance, theme-preview limitations and loading-state labels.

Checks on this documentation-only continuation:

- `python3 -m unittest discover -s scripts/tests -p 'test_audit_ui_components.py' -v`:
  four tests passed.
- Ten PNG SHA-256 values and 720×1600 dimensions matched the manifest.
- Local guide/evidence/handoff links resolve; `git diff --check` passed.
- Full scoped diff reviewed; original capture/Penpot files preserved.
- No Flutter tests/build for this documentation-only branch. #139/#145 runtime
  verification is separately recorded in their handoffs.

The exclusive device lease was released after QA group removal and restoration
of Browse Danbooru, font 1.0, keyboard preference and Midnight appearance with
dynamic color off. Colors initially showed “Default”; it now stores an explicit
Midnight choice because the editor has no null-override reset. This small
representation difference remains. The updated #145 APK remains installed;
navigation/search may leave transient history.

Local checks: `.worktrees/_artifacts/bookmark-ui-corrections-139/` and
`.worktrees/_artifacts/bookmark-ui-corrections-136-doc-tests.log`.
