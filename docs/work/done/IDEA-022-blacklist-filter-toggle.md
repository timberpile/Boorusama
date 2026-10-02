# Collapsed blacklist filter

Priority: Normal
Affected feature: Global, profile, and site-specific blacklist editors
Branch: `feature/blacklist-filter-toggle`
Agent: `/root/implement_22`

## Problem

The shared blacklist editor always shows its search/filter controls on entry,
using vertical space even when users are managing the list rather than
filtering it.

## Expected behavior

Hide the filter controls initially and expose a localized top-bar toggle.
Expanding and collapsing the controls must preserve the active filter and
filtered results. The toggle must expose its expanded state to accessibility
services.

## Acceptance criteria

- [x] Filter controls are hidden when an editor opens.
- [x] The top-bar toggle reveals and hides them.
- [x] An active query and its filtered results remain intact while collapsed
  and after re-expansion.
- [x] The toggle has localized accessible text and exposes whether filters are
  expanded.
- [x] Focused widget tests cover initial, expanded, collapsed, active-filter,
  and accessible-state behavior.

## Completion evidence

- TDD red: focused widget tests failed on the visible search field and missing
  toggle before implementation.
- TDD green: `fvm flutter test --no-pub
  test/core/blacklists/blacklisted_tag_filter_toggle_test.dart` passed (4
  tests).
- Full suite: `fvm flutter test --no-pub` passed (1,488 tests).
- Analyzer: `fvm flutter analyze --no-pub` reported the baseline 227 info-level
  findings and no additional findings.
- Android: Maestro flow on `emulator-5564` opened Your Blacklist, verified
  Search was hidden initially, showed the filter, and hid it again; 12 commands
  succeeded. No shared account data was changed.
- `git diff --check` passed.

## Progress

- Claimed in this worktree on `feature/blacklist-filter-toggle`.
