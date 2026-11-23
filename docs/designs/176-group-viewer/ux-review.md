# UX critique — group viewer study 176

**Latest design note (2026-11-18):** The earlier Custom Related reorder editor is withdrawn. Only Oldest/Newest is supported, with the same selector/state in Single and Timeline and the existing saved Related Bookmark preference. Related Groups default to Single. All older custom-order critique below refers to the archived prototype, not the current specification.

**Review type: author self-review, not an independent review.**

The user requested a UX specialist subagent. Available tools and plugin discovery exposed no executable subagent facility. No specialist was dispatched, no external reviewer supplied findings, and this document must not be represented as independent sign-off. Browser tests verify prototype behavior, not user understanding or native interaction quality.

## Method

Review the three variants against the issue's navigation contract, source-derived app structure, mode discoverability, separation of order and presentation, reading-position continuity, unavailable data, reversible changes, keyboard access, 320-pixel layout and 200% app text. Inspect rendered Chromium screenshots and exercise the same tasks across variants. Research references and baseline links are in the [design](../2026-11-18-group-viewer-modes.md).

## Findings and changes

| Severity | Finding | Response / evidence |
| --- | --- | --- |
| High | A Timeline scroll handler could replace the selected image with the first image of the visible row. In the reproduced case, image 4 became image 3. | Removed scroll-driven selection. Timeline scroll and explicit selection are separate; mode round-trips retain image 4 in all variants. Browser regression checks included. |
| High | Editing only a partial member set would misleadingly present a complete custom sequence. An already selected Custom mode also needed protection. | Disable starting or saving Custom while incomplete; hide its editor until membership is complete. Test both fresh and existing Custom states. |
| High | A restricted image could leak through a return/feed-preview surface even though the main viewer hid it. | Apply the fixture restriction to viewer, Timeline, editor and origin preview. Browser check verifies the return preview contains no art. This is not a full security audit. |
| Medium | Duplicate Order controls in the first A layout added clutter without adding a distinct action. | Removed the extra sort icon beside the segmented control. A single text-labelled Order row is available in every variant and mode. |
| Medium | A top-layer HTML dialog was centered in the browser and extended outside the phone. | Size and position it against the simulated device's visible area. Use a scrollable body with persistent dialog actions. This approximates a native constrained surface, not the exact app animation. |
| Medium | Back from hidden controls initially needed an extra step, treating chrome visibility as history. | Hidden chrome no longer adds a Back stop. Modal dismissal remains separate. A regression check covers exiting from immersive presentation. |
| Medium | Re-rendering member navigation moved focus in a way that stopped repeated arrow-key use. | Preserve a keyboard navigation path from the member controls; verify repeated navigation and dialog focus return. |
| Medium | A group-kind mode choice was lost for every new outer occurrence. | New occurrences use the last explicit mode for that fixture kind; returning occurrences keep their own checkpoints. Durable per-profile storage remains a proposal. |
| Medium | A dense bottom switch could compete with two navigation levels and actions. | Kept C as a comparison, not the recommendation. A avoids adding another bottom control row. True one-handed reach and gesture interference remain untested. |
| Low | Narrow and enlarged-text layouts could tempt reducing touch targets or removing labels. | Keep 48-unit primary controls, wrap at enlarged text, test structural overflow at 320 pixels and 200% app text. No screen-reader or full contrast certification is claimed. |

The tests also preserve Pool's three distinct choices, retain unavailable ordinal positions, verify ordering from both views, and check Save/Cancel/Undo. Source order is not made editable for Series or Pixiv.

## Remaining critique

**The prototype is still more explicit than the current viewer.** A group header, a mode row and a permanent outer navigation rail consume screen space. The dedicated rail is useful for explaining inner/outer navigation but may not be the right final production treatment. Compare a persistent rail against an end-of-group handoff and the existing toolbar navigation before committing to it.

**The word Timeline may imply chronology.** Here it names the app's image list, while Series and Works retain authored order. The separate Order label reduces the ambiguity, but does not prove it is solved. Test comprehension against `Images` or `Overview` while retaining familiar product terminology where possible.

**Single restores the last selected member, not whatever the user happened to scroll past.** This is intentional and protects identity. It might surprise someone who scrolls a long way in Timeline and presses Single expecting the top visible image. Tapping a tile is the explicit alternative. This tradeoff needs observation with users; changing it would require a carefully defined visible-anchor policy, not a nearest-grid-row heuristic.

**Custom ordering is more scope than a sort picker.** Local persistence, refresh reconciliation, profile isolation and asynchronous save failures require implementation work absent from the current oldest/newest enum. Keep the ordinary sort UI usable even if custom persistence is deferred.

**The fixtures underrepresent real media.** Six similar-ratio illustrations do not test comics, extreme aspect ratios, animation, video, long works, empty groups, deleted current members during refresh, mixed engines or changed authorization. The baseline code and documented contracts must guide implementation; a successful HTML demo is not evidence that those cases are solved.

## Brief for a genuinely independent UX reviewer

Review this branch's design and run `index.html` without assuming A is correct. Your role is to challenge the proposed interaction, not endorse the author's recommendation. Do not change product code.

Perform these tasks in A, B and C: open a Related group's fourth member; switch views; scroll without selecting; return; reorder that member; cancel and then save; undo; reach the final member; move to another feed item and return; open a Series and a Pixiv Work; encounter a restricted or missing fourth member; try a partial manifest; use keyboard-only navigation and 200% app text at 320 pixels.

Report each finding with severity, the exact scenario/control, expected versus observed behavior, user impact and a concrete alternative. Distinguish existing app behavior, proposed behavior and prototype-only limitations. Specifically assess mode discoverability, whether Timeline's meaning is clear, whether the two navigation levels are understandable, the extra outer rail's space cost, native Back expectations, action target clarity, and whether local custom order is proportionate to the task.

Return a preferred variant with tradeoffs, proposed revisions, and unresolved user questions. Do not claim user validation, accessibility compliance, or Android testing without actually performing it. Do not merge, create a PR, close #176, or treat this author self-review as prior independent approval.


## 2026-11-18 follow-up self-critique: user's screenshots

**Not an independent UX-specialist review.** The user supplied screenshots of the actual Pixiv Work Immersive and Detailed surfaces, a Pool Timeline, and a Related Timeline, and preferred compact option B. Comparing the initial concept with these images exposed material visual drift: a universal title header, a dedicated mode row and a permanent outer-feed rail would occupy space or replace UI that already exists. The revised `index.html` instead follows those four source surfaces, with a view action inside existing chrome.

The resulting shared visual shell has a real scope challenge: **Pixiv favorites/bookmarks apply to a Work, while a Pool/Related member viewer's standard actions apply to the current Post**. Do not collapse them into a generic favorite control. In the Pixiv Timeline tiles, show ordinal labels but no per-page hearts. In the Pool/Related Timeline retain existing tile actions and sort controls. Pools retain Ordered/Latest/Oldest; Series remains source ordered; Related custom ordering is a new, unapproved proposal.

Option B's view action is beside Info in Single and beside the overflow action in the Timeline count toolbar. B+ exposes a one-tap target icon and B− uses only the existing overflow, so the user can compare discoverability against footprint. A narrow Pool toolbar is the highest layout risk; button targets, overflow and enlarged text require native verification.

**Open issue:** A tile tap is a traditional drill-in, for which Back should plausibly return to the grid; explicit presentation switching should not necessarily add a Back-stack route. This difference, outer pager handoff, and restoring a hidden overlay are difficult to validate from HTML. The revised prototype chooses a documented navigation hypothesis, not an approved Flutter contract. Genuine independent UX review and native Android acceptance are still outstanding. Reference: [screenshot-aligned design](screenshot-alignment.md).
