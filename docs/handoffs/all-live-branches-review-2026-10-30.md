# All live implemented issue branches: review order and checks

Prepared for Timber's manual review after the complete source review, scoped
corrections, Android compilation and complete local test qualification of all
17 implemented open-issue branches. The order starts with small UI changes and
moves toward shared actions, accounts and persistent data. Human acceptance
and integration remain pending.

During this run, Timber reported already reviewing #113, #118, #114, #117 and
Group Neighboring Series (#68). Their reviewed commit IDs were not supplied;
this records user-reported review progress without inferring acceptance of
later source changes or authorization to integrate. Use the checklists for
remaining acceptance areas and relevant subsequent fixes.

Issue #55 (`feature/55-undo-reversible-actions`) remains **unstarted**, as explicitly
requested: its branch has zero unique commits and contains no Undo implementation.
Closed-issue retained refs #53/#76, deleted historical branches and report/policy
branches are outside this active implementation cohort. No PR, develop merge,
issue closure, branch deletion, force push or release was performed.

## Verified branch candidates

Every row has a successful Android dev debug build and complete local runner:
application, all 13 packages/CLI suites, both shell suites and 72 Python tests.
The router retains two declared individual skips per complete run. Scoped
analysis has zero errors and warnings; informational findings are shown below.
The table separates the checked runtime/test commit from subsequent documentation
commits. Per-branch handoffs record build commands, APK SHA-256, exact counts,
review decisions, reused evidence and limits. Any later combined candidate needs
its own verification.

| Order | Issue / branch | Checked runtime/tests | App / packages passed | Analysis infos | Published review handoff |
| ---: | --- | --- | ---: | ---: | --- |
| 1 | #91 `feature/91-branded-search-link-share` | `e8c880c2783fefe5a58b0b73d98bf3914157809f` | 5,480 / 1,608 | 0 | [fda30f41a](https://github.com/timberpile/Boorusama/blob/fda30f41a38f587be6dfbd710b04a2e60db718c3/docs/handoffs/91-all-live-review-2026-10-30.md) |
| 2 | #95 `feature/95-artist-links` | `7fa4e4f7fadd28cdf332c6855ac18e4fd28b3e9a` | 5,500 / 1,608 | 6 | [3fec25e39](https://github.com/timberpile/Boorusama/blob/3fec25e3929114ade8f32db3df153756644c176f/docs/handoffs/95-all-live-review-2026-10-30.md) |
| 3 | #97 `bug/97-follow-destination-identity` | `6056bd06cfd7510aec41c00562d7dfd37c8725a7` | 5,480 / 1,608 | 0 | [c9c8c649f](https://github.com/timberpile/Boorusama/blob/c9c8c649f19027f60ed3e59d208127e5a1ca2830/docs/handoffs/97-all-live-review-2026-10-30.md) |
| 4 | #98 `bug/98-search-overlay-surface` | `89e064d4f86b0acad62c11c96e6a085fe522ccc7` | 5,482 / 1,608 | 1 | [864166877](https://github.com/timberpile/Boorusama/blob/864166877fdc49fbba0a9a4be7e7ef86439e4e39/docs/handoffs/98-all-live-review-2026-10-30.md) |
| 5 | #99 `feature/99-selected-tag-suggestions` | `98d4b0ae68dded641475a0662318c56f65b625f7` | 5,495 / 1,608 | 0 | [2ea32c1e9](https://github.com/timberpile/Boorusama/blob/2ea32c1e92a6abb803906308de4ef4c6b2b5aede/docs/handoffs/99-all-live-review-2026-10-30.md) |
| 6 | #116 `feature/116-compact-follow-button` | `8c18fcfd68cb5084bb23373115752c1ab7b217d3` | 5,482 / 1,608 | 0 | [8ed94ba25](https://github.com/timberpile/Boorusama/blob/8ed94ba25c738da6327db7124c6d7b8e3c338438/docs/handoffs/116-all-live-review-2026-10-30.md) |
| 7 | #104 `feature/104-expanded-details-swipe` | `0b7bbb2c9630292eda16bcb769b8ac057199452e` | 5,483 / 1,608 | 0 | [d4037633c](https://github.com/timberpile/Boorusama/blob/d4037633c0a8ca26636e82a49003bb6f0870806e/docs/handoffs/104-all-live-review-2026-10-30.md) |
| 8 | #112 `feature/112-viewer-toolbar-layout` | `8213b6fbb87cb09d30d5056ad6667821371f22f6` | 5,528 / 1,608 | 0 | [c8fc7e4e0](https://github.com/timberpile/Boorusama/blob/c8fc7e4e05b1689279632027ecdcda7227beb70c/docs/handoffs/112-all-live-review-2026-10-30.md) |
| 9 | #106 `bug/106-live-undo-toast-insets` | `ebb9c8ecbbd3841e2546f2b59927a71eeaaf0db8` | 5,488 / 1,608 | 23 | [d51596638](https://github.com/timberpile/Boorusama/blob/d51596638a5a9916cf7979f686f3479ba04885cd/docs/handoffs/106-all-live-review-2026-10-30.md) |
| 10 | #107 `feature/107-local-post-sorting` | `6a9cff5883357ca049e5bdfb26c277730c17885a` | 5,533 / 1,608 | 0 | [c9018d389](https://github.com/timberpile/Boorusama/blob/c9018d389c74937846a1f41c55f455c51102df66/docs/handoffs/107-all-live-review-2026-10-30.md) |
| 11 | #113 `bug/113-collection-pagination` | `db64a26acc909acc552643720f47d03f31137515` | 5,518 / 1,608 | 1 | [4dcd43aa2](https://github.com/timberpile/Boorusama/blob/4dcd43aa2d14a8714e6be40c15aafdd3f8069a4c/docs/handoffs/113-all-live-review-2026-10-30.md) |
| 12 | #114 `feature/114-timeline-toolbar` | `9857ee5d87c6cc986a705dc0f1c9649e0ffdc844` | 5,505 / 1,608 | 2 | [eb0171656](https://github.com/timberpile/Boorusama/blob/eb01716560d9ee0fb04d28e61102772194207f76/docs/handoffs/114-all-live-review-2026-10-30.md) |
| 13 | #92 `bug/92-selection-share-image` | `5172d23cbbe2a18f5ca5d08151f46a21ce29b8ba` | 5,505 / 1,608 | 8 | [f6a57c998](https://github.com/timberpile/Boorusama/blob/f6a57c998d5675c1cffd6db1ca14ae4d0f572587/docs/handoffs/92-all-live-review-2026-10-30.md) |
| 14 | #108 `feature/108-selection-action-parity` | `937087386e8e39f33ffd843e9f2669b8c8e14303` | 5,483 / 1,610 | 7 | [ed54e3a34](https://github.com/timberpile/Boorusama/blob/ed54e3a346405be197e174fa10a7cb76e19f29a2/docs/handoffs/108-all-live-review-2026-10-30.md) |
| 15 | #117 `feature/117-pixiv-favorites` | `e05bb29f74343737c2571968e8aeda8e46e65e19` | 5,548 / 1,623 | 3 | [02da3db4e](https://github.com/timberpile/Boorusama/blob/02da3db4e43b399a1f04a1d01976ea37edaa4e97/docs/handoffs/117-all-live-review-2026-10-30.md) |
| 16 | #118 `feature/118-pixiv-following-artists` | `5b2ef956de4e809fbae70a51c0dfd0d4e8ad93e9` | 5,514 / 1,621 | 8 | [a96098365](https://github.com/timberpile/Boorusama/blob/a96098365fc96c23386e7cd6a4343058bdf5a4d5/docs/handoffs/118-all-live-review-2026-10-30.md) |
| 17 | #68 `feature/group-neighboring-series` | `ef78418942ddee4afc8c1af08c18517ee876ef29` | 5,432 / 1,603 | 127 | [405ef9ee9](https://github.com/timberpile/Boorusama/blob/405ef9ee9c7f0821d3601866373884015c5323f5/docs/handoffs/68-all-live-review-2026-10-30.md) |

The host restarted during this assignment. Interrupted checks were never counted
as passes; completed observed results were reconciled with unchanged commits,
persistent handoffs and surviving APK hashes. Raw logs for subsequent checks
are stored in durable ignored workspace artifacts. Complete passes were reused
only on the same runtime/test candidate, with documentation-only differences
verified. Existing native callback/finalizer, native-hook and toolchain notices
were not suppressed or claimed repaired.

## What to test, in order

Use the reviewed branch's APK/source and follow these checks. Repeat constrained
forms, menus and pickers at narrow width and enlarged text, with the keyboard
open where relevant. No device install or authenticated live-service acceptance
was newly performed by the agent in this all-branch pass; older device evidence is limited
to the candidates/scenarios in its original handoff.

### 1. #91 — `feature/91-branded-search-link-share`

1. Use the branded Search Share action in light/dark themes and at large text. Check icon size and tooltip, cancel once, and tap repeatedly during the system handoff: only one share should run.
2. Reopen the shared .bslink with Boorusama and confirm the query and originating site/profile.

### 2. #95 — `feature/95-artist-links`

1. Share an Artist link from a Danbooru Artist page; reopen its .bslink while the app is running and from a cold start. Confirm the same artist and site.
2. Repeat with another globally active profile and with the source profile unavailable. Check profile setup/selection and cancellation without borrowing unrelated credentials; inspect long names at large text.

### 3. #97 — `bug/97-follow-destination-identity`

1. Inspect a Follow destination picker's first frame with Home, folders and groups. Checkbox state must belong to the correct destination before any tap.
2. Select destinations, enter a folder, navigate back and reopen it, then confirm. Selections must retain their identities. Repeat at narrow width, enlarged text and relevant keyboard insets.

### 4. #98 — `bug/98-search-overlay-surface`

1. Scroll prior Search results, reopen the editor, and alternate Suggestions/Options. The editor must fully cover old results with an opaque surface.
2. Expand Options and open/close the keyboard at both Search bar positions. Closing/reopening must preserve the draft and selected tags without background-result interaction.

### 5. #99 — `feature/99-selected-tag-suggestions`

1. Select a suggested tag, its negative form, an OR term and a known alias. Selected canonical/alias suggestions should disappear immediately; removing the selection should restore them.
2. Type rapidly, switch profile/query and use an IME composing word. Cursor/composing state, raw/metatag behavior and the new profile's suggestions must remain correct. Check the desktop popup if used.

### 6. #116 — `feature/116-compact-follow-button`

1. Compare compact Follow/Following in Search and an Artist header. Check smaller paint, padded edge taps, count, busy icon and modified badge alignment.
2. Follow, cancel a destination picker and modify an existing Follow. Repeat at narrow width and enlarged text; noncompact controls must retain their previous sizing.

### 7. #104 — `feature/104-expanded-details-swipe`

1. On a phone in horizontal viewer mode, expand details and swipe media left/right. The post should change and details collapse; reopening must show the new post's metadata.
2. Try vertical metadata scrolling, nested horizontal content, text selection, zoom, video and rapid/mid-animation swipes. Compare disabled paging, vertical layout and large screens; assess gesture ownership and UX.

### 8. #112 — `feature/112-viewer-toolbar-layout`

1. Image Viewer Settings -> Toolbar: reorder using touch drag and move controls; transfer to/from More and choose an explicit replacement when full. Back discards, Apply survives restart, Reset restores each engine's native layout.
2. Test narrow/normal widths, enlarged text, rotation, short panes, keyboard and RTL. More stays physically right; outer actions overflow before central ones without rewriting saved order. Test all-More and settings export/import.
3. From More, exercise Bookmark, Share, chosen-quality Download, Comments, Favorite/unfavorite and votes on supported engines. Change post/profile/auth while open: no stale or wrong-account actions. Unavailable actions should return to their saved positions.

### 9. #106 — `bug/106-live-undo-toast-insets`

1. Remove a bookmark through the real Selection Manager and tap Undo while selection remains visible. Repeat in the viewer and close the viewer while the toast is alive; it must stay above current controls.
2. With Undo visible, open/close the native keyboard, resize selection controls, rotate, use large system text and background/resume. Undo stays reachable and executes once; expired/superseded Undo must not restore the wrong removal.

### 10. #107 — `feature/107-local-post-sorting`

1. In Bookmarks, compare highest/lowest score and newest/oldest upload, including ties and missing metadata. Group covers follow the same order. Combine source/tag filters with selection.
2. In a populated cached Topic Feed, change local sort during pending requests/automatic updates. No new remote sort request or Search history entry should be created; closing Search restores normal order. Check equal numeric IDs from different sites against blacklist rules.

### 11. #113 — `bug/113-collection-pagination`

1. Open small and multipage Danbooru/Szurubooru Pools, including unavailable members if available. Load More advances by ID slice, preserves source order and stops at the end. Change page size and order while open.
2. In finite numbered and infinite Search, reach the end, move back, refresh and retry after a network failure. Refresh while Load More is pending; stale completions must not overwrite new results or append duplicates.

### 12. #114 — `feature/114-timeline-toolbar`

1. Inspect Browse/Search/cached Feed toolbar and header at narrow width and large text. Toggle pinning, scroll and open filters/blacklist menus; verify sticky geometry and keyboard reachability.
2. Use several blacklist rule pages. Toggle, edit/delete a rule while open and change profile. Counts/pages must update without stale rows, and one site's match must not hide another site's equal numeric post ID.

### 13. #92 — `bug/92-selection-share-image`

1. From Selection Manager, share one/multiple posts as Image before opening viewer media. Available display samples must work when Original is absent; Original/video choices keep their separate availability.
2. Check known and missing media facts: Image stays centered without layout jumps or unsolicited image downloads. Test native share/copy, cancellation and retry.
3. For Pixiv manual credentials, replace the token, Verify and save. Unverified/failed replacements must not retain old account identity; confirm media sharing still works.

### 14. #108 — `feature/108-selection-action-parity`

1. Change selection from one post to several and back. Single selection exposes the corresponding viewer actions, including inline Share, Comments and ordinary single Download; multiple selection keeps batch actions.
2. Exercise Bookmark add/remove and nested groups at narrow width, enlarged text and keyboard. Change active/source profile while a popup is pending: retain the captured source or fail visibly, never borrow another account.
3. Test native Share, favorite/unfavorite and source-specific actions on configured engines, including a locally bookmarked post whose source is unavailable.
4. Open a long post context menu near the top and bottom of a narrow screen, with enlarged text and a keyboard where relevant. Scroll to Select and Comments; the final action must remain visible, tappable and execute once.

### 15. #117 — `feature/117-pixiv-favorites`

1. Verify Pixiv authentication, then open Favorites. Switch Public/Private, load multiple pages, refresh and retry failed pages. Empty filtered continuing pages retain working Load More; terminal pages stop it.
2. Switch profile/account/privacy during loading and change only a cosmetic profile setting. Old responses must not appear under a new account, and harmless edits must not break the page.
3. Replace a manual refresh token. Old identity clears immediately; Verify resolves the new account before save/Favorites access. Failures remain visible and late results cannot overwrite a newer draft. Also test normal OAuth.

### 16. #118 — `feature/118-pixiv-following-artists`

1. Open Pixiv Tools -> Following Artists while global Following Topics remains available. Compare Public/Private, load more, refresh and retry; errors remain visible without dropping known results.
2. Inspect avatar/name and zero-to-three supplied previews at narrow width and enlarged text. Missing previews keep cards usable, no requests fill missing slots, and explicit covers reset with artwork/artist/account changes.
3. Tap an artist with another profile globally active: normal Search opens in the source Pixiv profile using `user:<numeric-id>`. Switch account/privacy during loading and test manual token Verify. Live mute/unknown-payload and local-blacklist preview policies remain acceptance questions.

### 17. #68 — `feature/group-neighboring-series`

1. Use a disposable Bookmark Group to save a Pool/Series alongside individual Posts. Cards show whole-collection counts and open the full original collection even with another profile active. Removing the reference preserves saved members; test Undo.
2. Combine indexed required/excluded tags, exact source filtering and member-upload sorts. Refresh bounded metadata; test offline/missing-source behavior. Partial coverage follows the shown limitation and never retains a known nonmatch.
3. Scroll a group with over 40 saved Posts to later Series: requests stay bounded and settled tiles do not jump. Selection expands projected Series into Posts while an explicit Pool stays one reference. Test mixed group actions, duplication and export/import.
4. With two profiles on one host, assess the existing site-global Pool reference and strict originating-profile reopening behavior. A different persisted identity or combined score placement requires a separate decision and integration test.

## Decisions and integration boundaries

The current #68 Pool identity is site-global with strict originating-profile
reopening. A different account-key/migration policy needs an explicit decision.
#118's unknown-payload/mute and local-blacklist preview policy remains a live
acceptance question; no guessed filtering was introduced. #104 and #112 retain
trial UX choices for hands-on acceptance. Cross-feature score/Pool placement,
selection/actions and account/viewer combinations need testing after approved
integration; standalone green branches do not qualify an untested combination.

The separately requested durable-agent-file rule is committed locally on
`maintenance/durable-agent-artifacts` at
`5c15b27fdd00dcf681ddc8f53d2701ff3840b116`. It requires important agent-managed
logs, evidence, recovery state and handoffs to use durable workspace storage;
`/tmp` is reserved for disposable scratch. That new documentation branch has
not been merged or published under the issue-branch publication authorization.
