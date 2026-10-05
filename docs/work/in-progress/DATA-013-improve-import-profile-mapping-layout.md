# Make import profile mapping cards readable

Priority: Normal
Affected feature: Profile mapping cards in import review

## Problem

The reported Android screenshot shows profile information, target selection, and Create profile competing for width in one row. URLs wrap into narrow fragments and make the cards unnecessarily tall.

## Expected behavior and acceptance criteria

- Place the incoming profile name above its website and booru type, using the full card width for this information.
- Place the target profile selector and Create profile action in a row below the information, separated by localized “or” text. Give the selector the available flexible space.
- When screen width or text scaling makes that row unreadable, arrange the choices vertically with “or” between them. No overflow, clipped controls, or narrow fragmented URL columns.
- Keep the current target readable and distinguish same-named target profiles by website. Long profile names may wrap.
- Preserve accessible labels and the ability to change mappings established by DATA-007.
- Verify representative long names/URLs, narrow Android portrait screens, and enlarged text with widget coverage and visible UI validation.

## Context and dependencies

Layout approved by the user on 2026-10-05: information above; target selector “or” Create profile below; vertical fallback when needed. The screenshot contains rule34.xxx, danbooru.donmai.us, and gelbooru.com cards illustrating excessive URL wrapping.

Relevant code: `lib/core/backups/export_import/import/import_flow_page.dart`, profile mapping card. Coordinate with [DATA-012](../in-progress/DATA-012-default-and-edit-import-profile-mappings.md), which changes mapping defaults and continued editability. Repeated dependency messages are a separate workitem; this ticket does not change compatibility or planning rules.

Follow [development workflow](../../development_workflow.md) and [engineering guidelines](../../engineering_guidelines.md). Implementation is delegated in its dedicated branch/worktree.

## Claim and progress

- Claimed 2026-10-05 by coordinator `/root/import_coordinator`; session rooted at `/root`.
- Branch: `fix/data-013-import-profile-layout`.
- Worktree: `/home/timber/code/Boorusama/.worktrees/data-013-import-profile-layout`.
- Implementer: `/root/import_coordinator/data013`.
- Dependency: reviewed DATA-012 commits `9b6ff5ab4` and `ed174c313`, carried onto this dedicated branch from current local develop; these inherited commits are not DATA-013 implementation.
- Status: implementation pending; no integration or publication authorized.
