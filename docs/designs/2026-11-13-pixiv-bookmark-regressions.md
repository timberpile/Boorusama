# Pixiv Bookmark regressions and button options

Issue #141. Original diagnosis baseline: `e9d1056d0b15105db48e5ff4d1e0cbab7b203323`.
Updated 2026-11-14. Current runtime and exact verification evidence are in the
[local acceptance handoff](../handoffs/141-pixiv-bookmark-regression-acceptance.md).
Source diagnosis and hosted tests are not live Pixiv/device acceptance.

## Root causes established in source

`MediaGroupActions.build` returned its bare child when `NavigationActivity` was
false. `DestinationPageActivity.didPushNext` makes a covered route inactive,
including while its own Bookmark choice dialog is open. That removed the Work's
`PostActionToolbarScope` and disposed its button. The awaiting chooser then
returned at its unmounted guard instead of handing the selection to the real
Bookmark Group picker. Neither a double pop nor storage corruption was proved.

The same absent scope exposed the ordinary `BookmarkPostButton` fallback for
inactive neighboring Works. That fallback reads Page identity and uses the app's
selected bookmark color; the Work button reads Work identity and previously did
not set that selected color. Old Page-only records therefore produced a different
fill/color from Work records while moving between entries. This explains the
reported mismatch in source, but does not prove that it accounts for every frame
of real swiping, hydration or imported-data behavior.

The chooser also had no independent membership indicators, exposed advanced
choices for confirmed one-Page Works and did not bind continuation to the original
outer Work owner. Download had its own custom trailing-arrow composition rather
than a reusable button affordance.

A subsequent review found a separate layout defect in the first reusable button:
Material 2 constrains the whole icon slot to `iconSize`. A 24 dp slot cannot contain
a 24 dp main glyph plus a 16 dp chevron. `937ab4b...` reserves the composite slot
while keeping the actual main glyph size explicit. This also covers the 20 dp
Download variant; the minimum target remains 48 by 48 dp.

## Corrective behavior and invariants

Navigation activity suppresses input without removing Work action ownership.
Source loss leaves a disabled Work action, not an actionable Page fallback.
Work reference/access owns the state; a captured owner token and current
permission guard reject outer Work replacement, revoked authorization or unmount.
The chooser freezes the actual inner Page at entry, so a later inner Page change
does not silently change the target. A Page must belong to the Work and actor and
pass the existing availability restrictions. Unknown count is not one Page.

Direct tap remains Entire Work. Confirmed one-Page Works have no chooser or arrow.
Both choices use the same bookmark glyph, independent persisted fill/color and
membership count. Main-button selection continues to mean Work only. Opening a
menu does not save anything or change selection. Redundant Work/Page overflow
actions are removed; unrelated actions remain.

The approved labels are now committed, not an outstanding patch:

| Key | en-US | de-DE |
| --- | --- | --- |
| `content_viewer.bookmark_work` | Entire Work | Gesamtes Werk |
| `content_viewer.bookmark_page` | Current Page | Aktuelle Seite |

`e7354dfc...` changes exactly those values. The temporary patch is deleted.
Localizations are generated through the normal project path.

No membership, identity, codec, migration or Undo semantics were rewritten.
A historical Page-only bookmark does not imply Work membership, even for a
single-Page Work. Server-side Pixiv Favorites remain separate.

## Reusable action control

`KurumiActionIconButton` accepts an ordinary action, optional hold action and
`showDropdown`. `KurumiDropdownIcon` lays out the decorative trailing chevron;
it does not own domain selection or a menu. Bookmark and Download use this shared
control instead of custom arrow offsets/painters. Row direction provides RTL
placement. The main glyph does not inherit the enlarged composite slot size.

The chevron is not a tiny independent hit target. Tap and hold remain separate,
disabling the action disables hold too, and menu activation has no selected-state
side effect. Verify actual small Download callers, badges, narrow layouts and
large text locally; the 48 dp touch target is intentionally not pixel-neutral
relative to the old small visual button.

## Simultaneous Work/Page status — alternatives, not an approved redesign

| Option | Benefit | Cost or risk |
| --- | --- | --- |
| Two explicitly labelled Work and Page actions | Independent status is immediately clear; direct access and simple accessibility semantics | Two full targets and labels require responsive toolbar space |
| Split Work primary plus Page/target chooser | Groups related actions and makes the secondary path discoverable | Still needs two accessible targets; the secondary half must clearly mean chooser rather than immediate save |
| Work icon with a Page-state badge | Small visual footprint | Encodes four states, competes with membership count and can imply Work saving bookmarks every Page |

Recommendation: use two explicit targets when simultaneous status is required.
A split surface can group them visually but does not justify shrinking their hit
areas. Avoid an encoded combined badge as the default. Keep Work-primary/held-
chooser behavior in this corrective candidate until the owner chooses a material
redesign. All alternatives collapse to Work-only for a confirmed one-Page Work;
none silently changes direct tap to Page.

## Evidence boundary

The action tests mount production `MediaGroupActions`, route coverage, chooser,
Group picker/notifier and unified Hive storage. They cover direct/choice targets,
captured Page, keyboard Group creation, independent states, inactive neighbors,
single/unknown counts, cancellation and stale authorization/owner rejection.
Inputs are controlled; these are not real full-Viewer swipe tests.

Kurumi tests cover Material 2/3, RTL/LTR, 20/24 dp geometry, containment, minimum
target, disabled hold and distinct tap/hold dispatch. Existing commit guards,
persistence and restart/Undo tests remain required. A fresh hosted run exposed a
missing Riverpod extension import in the action tests; that compile failure and
explicit post-await mounted guards are part of the verification cleanup. Never
substitute an earlier summarized log or historical green count for the exact
current candidate's output. See the handoff for final results and remaining
Android/live Pixiv acceptance.
