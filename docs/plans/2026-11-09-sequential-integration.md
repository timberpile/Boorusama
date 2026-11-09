# Sequential integration from the combined rollout

The combined branch `maintenance/combined-testing-2026-11-08` is a **reference and test baseline**, not a merge source. Do not integrate the omnibus branch into `develop`. For each package use a branch based on the current `origin/develop`, explicitly select the needed changes, verify the complete final candidate, obtain independent review, run focused Android acceptance, and wait for user approval before publishing to `develop`. No PR or release is authorized by this plan. Preserve existing worktrees and source branch history.

## Integration order

| Package | Scope | Issue ownership | Specific acceptance gate |
| --- | --- | --- | --- |
| P1 | Shared timeline thumbnail cache and page continuation | #160, #162 | One viewport; bounded automatic continuation; Realbooru cold/warm scroll; cached Following history stays manual |
| P2 | Additive Favorites Sync and durable target assignment | #132 | Existing group memberships preserved; targets survive restart/token refresh; non-destructive Save & Fetch |
| P3 | Shared Post/Group references and capabilities | #154 | Group contracts without source UI changes; isolation/codec roundtrips |
| P4 | Unified Bookmark storage, hierarchy and UX | #155, #158 | Atomic v10 migration/rollback, direct and subtree views, exact old-style picker, subtree-delete Undo |
| P5 | Profile-independent Bookmark import | #142 | v4–v10 readers; exact self-backup Replace preview reports zero semantic changes |
| P6 | Public/offline Bookmark access | #143 | Cached media on restart; Gelbooru reattachment; Realbooru media, favicon, explanatory unavailable-by-site display |
| P7 | Existing remote source groups | #156 | Danbooru Pool/Related + Szurubooru identities, pagination and saved covers; genuine live acceptance |
| P8 | Pixiv Works, independent Page saves and Explore pagination | #140, #141, #161 | Browse/Search/Explore show Works; only two viewer presentation modes; Page/Work actions + downloads/shares |
| P9 | Folder collection sync | #144 | Read-only service/UI, direct Publish, named devices, hierarchical Receive, signed Stop Publishing withdrawal deletion |
| P10 | Native nhentai | #157 | Auth/API feasibility, profile switching, complete Gallery UI and Android acceptance after P9 |

#136 remains a separate Kurumi/Penpot design track. Structure and Unified use the already approved icon family A.

## Dependency and separation notes

The existing implementation history has a usable chain `#132 → #154 → #155 → #158 → #142 → #143 → #156`. P4 intentionally groups the two storage/hierarchy stages to avoid publishing a transitional v10 format. P8 groups Pixiv Work and Page actions to avoid releasing an incomplete viewer. P10 is intentionally held after the rest of the rollout.

Old task branches may contain obsolete intermediate code. Do not merge their heads blindly or copy the giant combined runtime commit `d4458f896`. Reconcile with current `develop` and port only feature-owned, reviewed changes and relevant fixes from the combined branch. Re-run the full regression for each new integration candidate, including schema/backup and current device behavior.

## Updated binding product decisions

- Pixiv native Work viewer offers two modes: **Image View** (only centered media) and **Details View** (media plus meaningful Work metadata/actions). Do not maintain independent overlay and layout switches that yield four states; respect system insets; hide single-image page counts; preserve image pan/zoom and deliberate Work/Page navigation.
- Folder Sync: sender sets an editable device name; receiver defaults to that name and may set a local override. A signed Stop Publishing withdrawal deletes the receiver's mirror only when no other effective publication/subscription keeps it; unreachable shared storage never signals deletion. Other local memberships survive. Mirror contents are not removable, duplicable or selectable as Bookmark destinations; local renaming/moving remain allowed. Direct Publish should not detour to the global checklist. Keep versioned storage but eliminate the redundant `BoorusamaSync` parent for new directories and safely handle existing publications.
- Picker: same icon for all groups; trailing chevron alone indicates children, with a subtle rounded surface for the right 20% navigation target; derive a subtle nested-membership indicator. Retain existing compact rows, Recent and `+ Group`.
- Persistent image cache retains ordinary URL/custom keys, not transient session or auth/policy epochs.

## Acceptance evidence

Each package handoff must contain exact commit, source parent, complete scope, automated test commands/results (not inferred from past combined runs), any independent reviewer findings, Android test result and non-destructive restoration evidence, and a short German manual checklist. Do not claim a package is ready until all relevant checks genuinely pass. After the user's explicit package approval, integrate as a separate conventional squash commit with relevant issue IDs.
