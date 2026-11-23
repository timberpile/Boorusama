# Current-fork capture set for Issue #136

These unchanged Android captures document existing behavior at
`fc601be07b2859eceb8297d10348c68d9611860c`; they are **not approved target designs**.
See the [audit](../2026-11-02-ui-design-system-audit.md) for findings and limits,
and [manifest.json](manifest.json) for APK/source provenance, per-image dimensions,
font scale and hashes. All 30 captures were imported into Penpot file
`New File 2`, page `136 / Mobile evidence (draft)`, on 2026-11-02. The manifest
records the file/page and per-capture board, image-shape and media IDs. Original
PNGs remain unchanged. All screenshots were reviewed for account/private content;
profile labels and artist data shown are public site metadata.

Phone: Android 17, 720×1600 physical at 320 dpi (360×800 logical), system text
scale 1.0. Exceptions: 21 uses system font scale 2.0; 22–23 use 1600×1000 physical
at the same density (800×500 logical). Active engine: Safebooru using Danbooru API.
Existing black default app appearance; persisted global/profile palette not
independently confirmed. 12 and 24–26 are **previews**, never applied global themes.

| Captures | Route / interaction state | Interpretation |
| --- | --- | --- |
| [01](01-following.png) | Following Topics empty | Primary action/reference state |
| [02](02-following-sort.png) | Following sort popup, Manual Order highlighted | Material selected-value menu |
| [03](03-following-editor-keyboard.png) | Follow query dialog, keyboard open, empty query | 14-pixel profile overflow; Next disabled |
| [04](04-navigation.png) | Menu navigation, top section | Existing engine destinations |
| [05](05-downloads.png) / [06](06-downloads-menu.png) | Downloads empty / action popup open | Kurumi action menu; not a sort selector |
| [07](07-settings.png) / [08](08-appearance.png) | Settings root / Appearance | Existing settings density |
| [09](09-storage.png) / [10](10-accessibility.png) | Storage / Accessibility | Existing card and control composition |
| [11](11-profiles.png) | Public profile list | No credentials/edit form captured |
| [12](12-theme-preview.png) / [24](24-theme-preview-alternative.png) | Midnight theme preview, grid/details pages | Simulated preview data, not live posts |
| [13](13-bookmarks.png) | Bookmarks while loading | Superseded for loaded state by 27–28; retain state label |
| [14](14-search-keyboard.png) / [15](15-search-query.png) | Search editor with keyboard / entered query | Search control composition |
| [16](16-search-empty-result.png) | No-result search | An actual empty result, not an engine failure diagnosis |
| [17](17-grid.png) | Browse grid | Visible decoded thumbnails; no loading benchmark |
| [18](18-viewer.png) / [19](19-viewer-details.png) | Viewer opening/media placeholder / details sheet | Route/details review, not full-resolution readiness or gesture acceptance |
| [20](20-following-editor-enabled.png) | Follow query filled, Next enabled, keyboard open | No follow submitted |
| [21](21-following-editor-text2.png) | Same dialog, text scale 2.0 | Overflow banner reports 106 pixels |
| [22](22-following-wide.png) / [23](23-following-editor-wide.png) | Wide Following / dialog with keyboard | 23 shows title/actions but no visible form content; reachability needs follow-up |
| [25](25-theme-preview-light.png) / [26](26-theme-preview-dark.png) | Basic light/dark preview | No global theme setting changed |
| [27](27-bookmark-groups.png) / [28](28-bookmark-default.png) | Loaded All/Default groups / Default group | No bookmark/group mutation performed |
| [29](29-artists.png) / [30](30-artist-details.png) | Artists list opening / expanded public artist | Danbooru-specific information layout |

For code entry points, use the [canonical-screen consumer matrix](../2026-11-02-kurumi-component-inventory.md#verified-consumer-references-and-canonical-screen-matrix).
Do not remove debug overflow banners or relabel loading/preview captures as
successful loaded production screens. They are part of the evidence.
