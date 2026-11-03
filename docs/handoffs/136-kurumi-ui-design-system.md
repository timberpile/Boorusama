# Local handoff — Issue #136: Kurumi UI design system

Continuation: [2026-11-03 timeline contract supplement](136-timeline-contract-20261103.md)
records later accepted rules and ten additional captures. The original source
audit, 30 captures and Penpot imports below retain their existing limits.

Date: 2026-11-02
Repository: https://github.com/timberpile/Boorusama
Issue: https://github.com/timberpile/Boorusama/issues/136
Branch: `feature/136-kurumi-ui-design-system`
Base: `origin/develop` at `74cdf43a5bd5205baa8f7cefb164986fe2656dd1`
Status: local source/screenshot audit completed; design baseline remains proposed.
The 30-screenshot Penpot batch is complete. Owner acceptance and integration
remain pending.

## Continue in the existing worktree

Read current `AGENTS.md`, `.agents/skills/design-change/SKILL.md`, the issue and
applicable workflow docs. Reuse this task branch's registered isolated worktree;
inspect branch ownership and local changes before attaching or fetching. Preserve
the primary checkout and other worktrees. No PR, push, develop integration or
issue closure was authorized in this continuation. Keep #136 open while its
review/design baseline remains incomplete. Use `Refs #136` in commits.

## Evidence now available

- [Source and interaction audit](../designs/2026-11-02-ui-design-system-audit.md):
  full-tree lexical scan, actual limitations, prioritized proposals and device
  findings. The scan found 3,382 included Dart files, 148 Kurumi declarations,
  1,569 app Kurumi constructor/helper candidates, 967 Material candidates,
  124 review candidates in 46 files, and no read errors. These are lexical
  candidates, not widget instances or style violations.
- [Component inventory](../designs/2026-11-02-kurumi-component-inventory.md):
  73 component implementation files plus ten canonical-screen rows, with
  manually verified consumers, wrappers, Material aliases and engine variations.
- [Proposed guide](../ui_style_guide.md): component selection, current theme-role
  mapping, input/menu behavior and repeatable visual-drift review. No new numeric
  scale or broad replacement policy was approved.
- [Thirty current-fork screenshots](../designs/136-evidence/README.md) and
  [capture manifest](../designs/136-evidence/manifest.json): retained in the repo
  and imported into Penpot with manifest-to-board mappings. Preserve loading/preview
  labels and debug overflow evidence. Do not substitute upstream screenshots.
- [Penpot strategy and actual draft IDs](../designs/2026-11-02-penpot-design-strategy.md):
  verified draft foundations/components and all 30 imported capture boards.
- [Independent review prompt](../designs/2026-11-02-ux-expert-review-prompt.md):
  used by a Luna Max reviewer for source, screenshot and counter-review cycles.
  The primary agent checked the resulting findings against code and captures.

## Important findings and decisions

1. Follow Topic's profile selector visibly overflows by 14 pixels at 360×800
   logical pixels with the keyboard open; Android system font scale 2.0 increases
   the banner to 106 pixels. Source suggests constraining the dropdown selected
   slot (`isExpanded: true`) before changing component families. This is a fix
   hypothesis, not an implemented or tested fix.
2. At 800×500 logical pixels with the keyboard open, the same dialog shows its
   title/actions without visible form content. Check short-height reachability
   before choosing a layout change; the screenshot does not establish all
   possible scroll/assistive paths.
3. Built-in primary label pairs have calculated contrast of 3.33:1 (light) and
   3.51:1 (dark/AMOLED). Direct error-on-surface text also needs review. Scope this
   to actual preset consumers, preserving dynamic/profile themes and state
   overrides. Do not silently change palettes during documentation work.
4. Following Topics' native selected-value menu and Downloads' Kurumi action
   menu visibly differ but have different semantics. Both tested Back dismissal
   paths worked. Preserve selection highlighting, focus and anchor behavior;
   no blanket Material replacement is justified. `PopupMenuActionLabel` contains
   icon/text; it does not itself add a checkmark.
5. The dev gallery still labels identical Kurumi implementations Existing/Kurumi.
   Propose an honest component/state reference. No runtime/gallery edit was made.
6. #105 owns global radius decisions. Do not reopen completed #50/#130 solely
   for this audit. No new follow-up issue was created.

## Verification and restoration

Checked runtime source: `fc601be07b2859eceb8297d10348c68d9611860c`, unchanged from
its develop base. The continuation changes docs, screenshot evidence and the
scanner/tests only. The scanner now recognizes selected named constructors,
excludes `generated/` trees and records dirty-checkout state.

Passed on the final scanner implementation:

- `python3 -m unittest discover -s scripts/tests -v`: 76 tests, including four
  expanded audit fixtures.
- `python3 -m py_compile scripts/audit_ui_components.py scripts/tests/test_audit_ui_components.py`.
- Full local scanner run; documentation/source/image link and capture hash checks.
- `git diff --check` and review of the full scoped diff.

FVM 3.47.2 dependency/CLI setup and `./gen.sh` initialized missing ignored outputs.
`fvm flutter build apk --debug --flavor dev --no-pub` passed; warnings included
AGP/Kotlin support notices, SDK XML version skew and the documented native-hook
`File modified during build` message. No application tests or complete Flutter
regression were run for this docs/audit-tooling milestone. Integration still
requires the final combined candidate's full local suite.

Audit APK SHA-256:
`56e6955a78a75994b3aa184bd70fccdfcb6a04d2d6fe5d6ab168bbb877b0bf6e`;
installed hash matched. Maestro controlled an exclusively leased emulator. After
capture, the original dev APK was restored and its hash rechecked:
`b2f7e6915803859e0348ae77780dc0c5d748a1e87d028f902ce968b8e8a9f9bb`.
Display 720×1600 / 320 dpi and system font scale 1.0 were restored, and the lease
was released. No app data reset, account mutation, follow/bookmark creation or
download was performed. Normal search/navigation can update transient/history
state; no claim is made that every preference/history byte is unchanged.

Build/test logs, scanner JSON/Markdown and the independent review are in durable
ignored `.worktrees/_artifacts/136-kurumi-ui-design-system/`. Shared findings and
screenshots needed for another machine are in the tracked documents above.

## Remaining review boundary

The owner-requested 30-image Penpot batch is complete in `New File 2`, page
`136 / Mobile evidence (draft)`. Capture counts, image dimensions, source metadata
and board containment were verified; Penpot file validation returned no errors.
Phone/wide exports were visually checked and a named version was saved. Use the
capture manifest's design IDs for updates; avoid duplicate imports. Keep these
current-code references distinct from approved target designs. Menu/chip studies,
additional states and reviewed canonical designs still gate Penpot acceptance.

Obtain owner acceptance of the proposed guide and focused remediation scope
before significant UI implementation. Full applied light/dark/dynamic/profile
coverage, desktop pointer/focus, TalkBack, profile credential forms, live mutation
and exhaustive loading/error/selection states remain unverified. Reuse current
screenshots only within their recorded state/source limits.
