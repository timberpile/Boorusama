# Decision 2 — Work/Page Interactions and Group UI

**Status:** Design recommendation informed by the user's current preferred gestures. Do not confuse locally saved Boorusama bookmarks with Pixiv account bookmarks. No runtime change.

## First: the action targets

A multi-page Work is **one source artwork**, while the selected Page is **one image Post**. They may have separate local Bookmark Group memberships and portable links. Pixiv server bookmarks, when supported, address the **whole source Work** using the real illustration ID.

Example: Work 120, selected Page 2 of 5:

| Action | Default target | Alternate target / why |
| --- | --- | --- |
| Local Bookmark icon | **Save Work** (one typed local reference, existing Bookmark Picker) | **Hold Bookmark**: choose Save Work or Save Current Page; Page uses existing Post identity |
| Pixiv source bookmark/favorite | **Work** plus authenticated account | Public/Private state is an account action, not a Page variant |
| Download icon | **Current Page** media | **Hold Download**: Download All Pages, with queue/progress/cancel |
| Share icon | Opens the existing Share Sheet | Both portable Work and Page references appear clearly, without duplicating everything |
| Open on Source Website | **Work** for Pixiv | No fabricated Page-specific Pixiv URL unless a real source feature is verified |
| View/Copy Image Link | **Current media/Page** | Still Page-specific; URLs may be temporary and should not be treated as stable identities |
| Find on Other Profiles | Source artwork query or exact Page file match, depending on search scope | Existing Pixiv cross-profile logic needs the real Work ID, never synthetic Post ID |
| Tags, descriptions, comments | Scope depends on source API | A Work description should not be reproduced as a fake page-specific fact |

## Preferred compact mobile interaction

**Overview** (artist/title/description below selected image):
- Show the familiar compact Work-level action strip with real semantic icons; no second persistent toolbar.
- Normal tap on the local Bookmark control opens the existing group picker for **the whole Work**.
- Holding that same Bookmark control opens a compact Kurumi choice: **Work** (stack icon) / **Current Page** (single-image icon). Then use the same Bookmark Picker, scoped to the chosen target.
- Normal tap Download downloads **the current Page**; holding Download offers **Download All**. Group-wide bulk download uses the current download queue with progress/cancel and permissions. Do not eagerly fetch every member in the UI isolate.
- Keep page-specific, less frequent operations in the existing overflow menu, using the same action icons and a divider. Use `Work` / `Current Page (2/5)` as section labels with stack/image icons only as explanatory affordances.
- Long press is a shortcut, **never the only way** to access Page bookmark or Download All. The equivalent commands belong in accessible overflow entries (keyboard, accessibility services and desktop). Do not intercept existing image long-press gestures.

**Image View** stays media-first: no permanently visible toolbar, with a subtle page counter for a multi-image Work. A tap can reveal the Overview; back/system navigation remains recoverable. A Work boundary is not crossed inadvertently when paging through image Pages.

**Single-page Works:** The Work and its Page can still be distinct local identities, but do not show two visually identical controls unless the difference matters. An explicit menu can retain Page-specific save/share where supported.

## Share Sheet: only duplicate what is different

The existing UnifiedPostShareSheet has **Media** and **Links** segments, with native source/post/image links plus a Boorusama portable `.bslink` link. Inspecting the current code distinguishes:

| Share item | Work or Page? | UI recommendation |
| --- | --- | --- |
| Pixiv source URL | Work (artwork ID) | One `Pixiv Work` link; not duplicated |
| External source URL | As supplied by upstream Post metadata | Leave as its own source link; do not infer it represents a Page |
| Image URL / actual image bytes | **Current Page** | Keep in Image/Media section, existing semantics |
| Raw numeric ID | Work ID + Page position as separate display facts | Avoid exposing synthetic page Post ID as though it were the true Pixiv ID |
| Boorusama portable Link File / URI | **Different identity** for Work vs Page | Two compact, clearly labeled options: `Work` and `Page` under a `Boorusama` heading |

**Recommended compact copy/share UI:** `Boorusama` heading with side-by-side **Work** and **Page** tiles (or rows on a narrow device); each tile offers Copy Link and Share Link File. Shorten the existing long `Boorusama Link File` row to this grouped section rather than generating several repetitive labels. Preserve the v1 `.bslink` envelope and validate each URI separately. Old recipients may reject new Work link kinds safely.

Do not duplicate media sharing, native source links or the source website URL just to fill two columns. The current Pixiv Post key `work-page:<workId>:<pageIndex>` already supports Page links. A Work link must be a validated, new group reference; its URI format is finalized in Decision 1.

## What about Danbooru, Related or nhentai?

**Danbooru Pool/Series/Collection:** Keep the existing **Header/Description + Post Timeline**. Group actions live in the Pool header/menu, and each Post retains the standard single-Post action toolbar. Do not force a Pixiv media-first Work Action strip on every group. Source category differences do not justify a second group implementation.

**Danbooru Related Family:** Keep direct-family gallery and ordinary Post actions; family bookmark/share uses canonical parent/anchor reference in group-level controls. Recommendations are distinct from direct parent/child membership.

**Szurubooru Pools:** Reuse the Pool/group header and Post timeline pattern; do not imply native source capabilities unavailable for that engine.

**nhentai Gallery:** Can share the same group/member infrastructure. Initial UI can be cover/details followed by an ordered Page timeline, or enter the shared media-first Page viewer, using data-source capabilities. Whether it gets Pixiv-style image-first composition is a **presentation choice**, not a reason to invent a `Gallery` base class. Images/pages are regular Post-level local operations where their stable IDs can be validated. Any upstream server Favorite is independent and opt-in.

## Supporting source capabilities, not a generic action framework

Use existing `BookmarkPickerRequest` variants and `Post` operations. New group reference actions pass an explicit group target. A lightweight engine capability determines whether a Work/Group can be source-bookmarked, shared, downloaded in bulk or loaded anonymously. Keep auth policy and account scope separate from local bookmark identity.

The current Pixiv repository uses `EmptyFavoriteRepository` via the default base: server bookmark **write** requires [Support Pixiv Artwork Bookmark Actions (#124)](https://github.com/timberpile/Boorusama/issues/124). Whole-Work local membership requires [Bookmark Pixiv Works and Images (#141)](https://github.com/timberpile/Boorusama/issues/141).

## Concrete cases to test

- A Work and Page 2 are both saved in different Bookmark Groups; removing one does not remove the other.
- A normal Bookmark tap targets Work even after changing images; hold offers Work/Page without an accidental immediate toggle.
- Screen reader, keyboard and overflow provide non-hold access to alternate actions.
- Page download uses the selected page's media; Download All doesn't treat inaccessible pages as successful downloads.
- Two `.bslink` options differ; existing source and image links stay accurate. Neither link contains credentials.
- A Danbooru Pool gallery still has per-Post actions and separate group actions without duplication.
- Missing Page 1 does not relabel Page 2, and share/download/save do not unexpectedly target a neighbor.
- Rapid paging cannot complete an async Bookmark Picker request against a different Page or profile.

## Proposed decision

Adopt the **compact default + long-press alternate + accessible overflow fallback** for Pixiv Works, with Work-level Share and Page-level Share in the existing Share Sheet. Retain existing Group Header + Post Timeline UIs for Pools/Related. Treat nhentai's eventual visual composition as separately selectable. No new global action-command framework.

### Evidence

- [Existing UnifiedPostShareSheet](https://github.com/timberpile/Boorusama/blob/e306ff533/lib/core/posts/shares/src/unified_post_share_sheet.dart)
- [Existing Pixiv page link grammar](https://github.com/timberpile/Boorusama/blob/e306ff533/lib/core/posts/links/boorusama_post_link.dart)
- [Existing Bookmark Picker scopes](https://github.com/timberpile/Boorusama/blob/e306ff533/lib/core/bookmarks/src/types/bookmark_picker_request.dart)
- [Pixiv official Bookmark semantics](https://www.pixiv.help/hc/en-us/articles/235646967-What-are-Bookmarks)
