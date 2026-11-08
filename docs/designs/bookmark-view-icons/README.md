# Bookmark view-mode icon candidates

Design study for the [Bookmark remediation contract](../2026-11-08-bookmark-review-remediation.md), not an accepted runtime icon change. No Penpot document has been modified. The user should select a family before implementation; other remediation work can proceed independently.

![Two candidate icon families](preview.svg)

| Family | Structure | All Bookmarks | Assessment |
| --- | --- | --- | --- |
| A: section versus grid | [Folder section plus direct tiles](a-structure.svg) | [One uniform content grid](a-all.svg) | Recommended: corresponds to the actual two layouts, without an organization-chart glyph. |
| B: nested versus flattened | [Nested collection](b-structure.svg) | [Content stack](b-all.svg) | More conventional imagery; less literal about direct items beneath groups. |

All four are standalone transparent 24x24 SVGs with a 1.75-unit rounded stroke, basic editable paths/rectangles, no bitmap, font, script or external dependency, and `currentColor` rather than a hardcoded theme palette. The preview board uses presentation colors only. Verify at actual 20/24dp sizes, not just enlarged.

For Penpot, import the four individual files rather than treating the comparison board as one icon. Keep names `Bookmark view / A / Structure`, `Bookmark view / A / All Bookmarks`, and equivalents for B. Verify import preserves strokes/viewBox and explicitly assign the semantic content color if an importer does not inherit currentColor. Put only the chosen family into the component library; keep the other as a draft alternative. Do not claim a 1:1 app mockup or Penpot publication from these assets.

In the app the icon denotes the current view, and its localized tooltip/semantics announces the action to switch. Keep the Header's existing accessible hit target, selected-state semantics and per-group preference. The All Bookmarks icon does not promise expansion of remote Pool/Work/Gallery members. Do not couple icon choice to new sorting or timeline layout behavior.
