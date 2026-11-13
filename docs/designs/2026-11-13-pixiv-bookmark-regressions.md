# Pixiv Bookmark regressions and button options

Issue: #141. Investigated against `e9d1056d0b15105db48e5ff4d1e0cbab7b203323`.
Status: source diagnosis and remote candidate preparation; not device acceptance.

## Confirmed source findings

`MediaGroupActions.build` returned its bare child whenever `NavigationActivity`
was false. `DestinationPageActivity.didPushNext` makes a covered route inactive,
including while its own Bookmark chooser dialog is open. The return removed
`PostActionToolbarScope`, so the Work button was disposed. After the choice was
popped, `_choose` returned at its `!mounted` guard instead of opening the real
Bookmark destination picker. `Navigator.pop` and the row's optional anchor hide
were not a demonstrated double-pop defect.

The same absent scope made `SimplePostActionToolbar` use its normal
`BookmarkPostButton` fallback while rendering inactive neighboring Works. That
button reads **Page identity** and uses `context.colors.upvoteColor`; the Work
button reads **Work identity** and previously did not set a selected color.
An old Page-only bookmark therefore yields a different result than a newly saved
whole Work. This explains both directions of the reported white/orange and
filled/unfilled transitions without inventing corruption of `idByContent`.
There is no independent device reproduction or proof that these are the only
causes of every reported frame. Actual paging, hydration and imported data still
need the local acceptance matrix.

The chooser also lacked per-target membership indicators, always offered its
advanced affordance regardless of a confirmed one-Page count, and did not bind
its continuation to the original outer Work owner. Download's old chevron was
another custom painter: it composed a wider glyph than its nominal 24 dp canvas,
not a reusable trailing-icon API.

## Candidate changes and invariant

Navigation activity now suppresses input without removing Work action ownership.
Source loss gives a disabled action rather than an actionable Page fallback.
Work reference/access key owns the widget; a captured owner token and current
authorization guard reject a rebind, revoked actor, or disposed continuation.
Inner Page changes do not replace the Page captured when the chooser opened.
A Page choice must belong to the actual Work and actor and pass the existing
restricted/source checks. Unknown count is not treated as one Page.

Both choices use `Symbols.bookmark`, independent persisted fill/color and their
own membership count. The main button continues to represent **Work only**;
opening a menu does not change that status. Work uses the existing app bookmark
selected-color role. Work/Page remain separate records; no migration or inferred
Work membership is introduced. One-Page Works offer only the direct Work action.
Redundant Work/Page overflow entries are removed; other actions are retained.

`KurumiActionIconButton` composes an ordinary action and optional hold action with
`showDropdown`; `KurumiDropdownIcon` lays out a trailing chevron within bounds.
It does not infer saved state or own a domain menu. The chevron is decorative,
not an inaccessible tiny second hit target. The standard target is at least
48 x 48 dp, including the visually smaller Download variant; verify its callers
on narrow layouts. Bookmark and Download share this presentation. RTL placement
comes from Row direction, not fixed bottom/right coordinates.

The exact approved text changes are supplied in
[`141-bookmark-labels.patch`](../handoffs/141-bookmark-labels.patch). **They are
not yet applied to the large translation resources.** Apply them and regenerate
localizations before running the new label-based tests. This candidate is not
complete until that small outstanding source change is committed.

## Simultaneous Work/Page status: proposals, not approved implementation

| Option | Benefits | Costs and risks |
| --- | --- | --- |
| Two separately labelled Work and Page actions | Clearest independent status and direct access; straightforward semantics and tests | At least two full touch targets; two identical bookmark glyphs need explicit labels; a crowded toolbar must adapt rather than shrink hit areas |
| Split Work primary + Page/target chooser | Preserves the primary Work action and a discoverable secondary target; independent indicators on one visual surface | Still needs two accessible hit targets, not two 24 dp halves; clearly label the secondary action as a chooser, not an immediate save; shared borders/focus are additional UI work |
| Combined Work icon with Page badge | Smallest visual footprint | Four states require learning a legend; a small badge competes with group count, is hard at scale/contrast, and can imply that saving Work saves every Page |

**Recommendation:** use two explicit Work/Page targets when simultaneous status
is a firm requirement; they have the least ambiguous state and action model.
A split surface is a reasonable visual grouping, but does not legitimately save
hit-target width. Avoid an encoded combined badge as the default. Keep the
current approved Work-primary/held-chooser behavior in this corrective candidate
until the owner selects a material redesign. All alternatives collapse to the
single Work action for a confirmed one-Page Work. Do not silently change direct
tap from Work to Page. The same glyph in the chooser is already approved and is
not contingent on this separate toolbar decision.

## Regression evidence boundary

New action tests mount production `MediaGroupActions` with real route coverage,
then exercise the production chooser/picker/notifier and unified Hive repository.
They cover direct tap, both choices, captured Page, keyboard Group creation,
independent states, inactive neighbors, unknown/single counts, cancellation,
source loss, outer Work replacement and unmount. Source/provider inputs are
controlled to avoid networking. This is not a full viewer swipe/device test.

Kurumi tests cover trailing containment/RTL, minimum target size, disabled hold,
independent tap/hold dispatch, and no selection mutation on menu activation.
Existing real commit-guard and restart/Undo tests remain relevant. No new Dart
format/analyzer/Flutter test, emulator, live Pixiv or independent review result
is claimed. Historical green results belong to the old runtime only.
