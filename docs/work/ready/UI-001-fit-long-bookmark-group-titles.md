# Fit long bookmark-group titles without premature truncation

Priority: Normal  
Affected feature: Bookmark-group overview cards and opened group's AppBar title  
Status: Unclaimed

## Problem

Bookmark-group overview titles wrap to a second line but then end in an ellipsis. Titles in the opened group's AppBar also truncate, even though fitting the text within the already available title box could make more of the name visible.

## Expected behavior and acceptance criteria

- [ ] In the opened group's AppBar, preserve the existing toolbar and title box dimensions. Fit the **largest** font size up to the normal text style that allows the whole title within the available width and height, considering one or multiple wrapped lines rather than always shrinking to a single line.
- [ ] Use a minimum base font size of **12 sp**, respect Flutter text scaling, and fall back to a sensible ellipsis only if all the text still cannot fit at that minimum. Short titles keep their normal font size.
- [ ] The fitting calculation accounts for line height, available width, actions/back navigation, and long/unbreakable words. No clipping, text overlap, new toolbar height, or unnecessary large-text layout overflow.
- [ ] In the bookmark-group overview, show full group titles at their normal title font size with wrapping and content-responsive **card height** rather than the current two-line ellipsis. Maintain usable preview thumbnails, the card tap target, and unobscured Rename/Duplicate/Delete overflow actions.
- [ ] The overview is currently a fixed-square `GridView`, not a list. Adapt its grid/card sizing deliberately so varying title lengths can expand vertically without losing the responsive column layout or colliding with neighboring cards; do not assume a `ListTile` height fix is sufficient.
- [ ] Cover short, two-line, three-or-more-line, very long and unbreakable titles, narrow screens, 2x text scaling, and localized strings. Include widget tests for text fitting and a realistic grid/card layout; validate on Android UI.

## Context

The opened bookmark listing uses `BookmarkAppBar` and `BookmarkScrollView`. The overview uses `SliverGridDelegateWithFixedCrossAxisCount`, and `_GroupCard` overlays a title with `maxLines: 2` and `TextOverflow.ellipsis` on the preview.

- [Bookmark AppBar](../../../lib/core/bookmarks/src/widgets/bookmark_appbar.dart)
- [Bookmark scroll view](../../../lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart)
- [Bookmark-group overview](../../../lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart)

Dependencies: None.

## Decision

2026-10-08: Prefer automatic font fitting inside the existing AppBar title area, with a 12 sp lower bound. In the group overview, expand cards to display titles at normal size instead of reducing their font or truncating after two lines.
