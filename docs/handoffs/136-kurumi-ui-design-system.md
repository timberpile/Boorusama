# Local agent handoff — Issue #136: Kurumi UI design system

Date: 2026-11-02
Repository: https://github.com/timberpile/Boorusama
GitHub issue: https://github.com/timberpile/Boorusama/issues/136
Task branch: `feature/136-kurumi-ui-design-system`
Starting base: `develop` at `74cdf43a5bd5205baa8f7cefb164986fe2656dd1`
Status: initial design and audit artifacts prepared; **not accepted or integration-ready**.

## Mission

Continue the evidence-driven Kurumi UI audit on this same issue branch. Turn the provisional component inventory and style guide into a validated, practical design-system reference based on the actual app and current-fork screenshots. Preserve compact layout, power-user workflows, existing navigation, engine-specific behavior, and performance. Do not perform an app-wide redesign or blindly replace Material controls.

## Safe checkout and ownership

1. Read the current `AGENTS.md`, `.agents/skills/design-change/SKILL.md`, `docs/issue_workflow.md`, and the applicable parts of `docs/development_workflow.md` before modifying code.
2. Fetch `origin/develop` and `origin/feature/136-kurumi-ui-design-system`. Inspect `git worktree list --porcelain` and existing local branches first. If a worktree already owns this task branch, reuse it.
3. If this branch has no local counterpart or worktree, create an **isolated** worktree from `origin/feature/136-kurumi-ui-design-system`, for example:

   ```sh
   git fetch origin develop feature/136-kurumi-ui-design-system
   git worktree list --porcelain
   git branch --list feature/136-kurumi-ui-design-system
   # Only when the local task branch does not yet exist:
   git worktree add --track -b feature/136-kurumi-ui-design-system \
     .worktrees/136-kurumi-ui-design-system origin/feature/136-kurumi-ui-design-system
   ```

   If the local branch already exists but is unattached, attach that existing branch instead of using `-b`. Never reset or disturb the primary checkout, other branches, or uncommitted work.
4. Continue committing coherent milestones on this branch. Preserve #136 in the commit context; do not use `Closes #136` before completion in approved `origin/develop`.

## Prepared files and intended authority

| File | Role |
| --- | --- |
| `docs/ui_style_guide.md` | **Proposed** Kurumi-first style guide; needs screenshot-backed review and acceptance |
| `docs/designs/2026-11-02-kurumi-component-inventory.md` | 73 Kurumi component implementation files and public declaration families |
| `docs/designs/2026-11-02-ui-design-system-audit.md` | Source-level reuse evidence, divergence candidates, screenshot matrix and limitations |
| `docs/designs/2026-11-02-penpot-design-strategy.md` | Curated component library and ~10 canonical-screen proposal; no live Penpot document |
| `docs/designs/2026-11-02-ux-expert-review-prompt.md` | Three-cycle, read-only expert reviewer prompt for source + current-fork screenshots |
| `scripts/audit_ui_components.py` | Python lexical inventory tool; writes reports into ignored `.worktrees/_artifacts/` |
| `scripts/tests/test_audit_ui_components.py` | Four synthetic-input tests for comments, string masking and call-site discovery |
| This handoff | Branch continuation instructions; not an additional task tracker |

The prepared audit is based on connected GitHub source inspection, not a completed full checkout scan. The counts represent **files**, not widget instances, unique classes or globally verified call-site totals. `KurumiMaterialChip` and related types are Material aliases, not necessarily custom-painted widgets. Direct Material usage is only a review candidate.

## First actions on the local checkout

1. Confirm this branch still contains the intended artifacts and has no unexpected upstream changes; record the actual HEAD SHA and any divergence from `origin/develop`.
2. Run:

   ```sh
   python3 -m unittest discover -s scripts/tests -p 'test_audit_ui_components.py' -v
   python3 scripts/audit_ui_components.py \
     --output-dir .worktrees/_artifacts/136-kurumi-ui-design-system/audit
   git diff --check
   ```

3. Read the generated `ui_component_inventory.md` and `ui_component_inventory.json`. Check false positives/negatives in representative call sites and improve the script/tests when justified. It is intentionally **lexical**, not a Dart AST or UI renderer; do not equate a call count with visual inconsistency.
4. Extend the existing component inventory with verified consumer references and a useful screen-to-component usage matrix. Distinguish Kurumi primitives, Material aliases, app wrappers, feature-specific widgets, and legitimate platform or engine variants.

## High-priority evidence to reproduce

- **Menu consistency:** `lib/core/search/following_topics/src/pages/following_topics_page.dart` uses Material `PopupMenuButton`/`PopupMenuItem` around lines 339–409; `lib/core/download_manager/src/pages/download_manager_page.dart` uses Kurumi menus around lines 142–153. Compare rendered density, anchoring, focus, keyboard navigation and dismissal before recommending migration.
- **Dialog/input consistency:** the Following Topics page directly uses Material dialogs and a text field. Check sizing, IME behavior, scrollability and screen-reader semantics before proposing replacements.
- **Token opportunities:** Kurumi button, settings-card and searchable-sheet implementations include literal dimensions. Identify repeated meaningful choices, but do not introduce a new global radius scale: [#105](https://github.com/timberpile/Boorusama/issues/105) owns that decision.
- **Gallery validity:** `lib/dev/kurumi_gallery.dart` labels Existing/Kurumi variants, but multiple pairs instantiate identical components. Propose a truthful component-state gallery, not fake before/after comparisons.
- **Known good reuse:** `NoDataBox`, app searchable-sheet wrappers, `AdaptiveButtonRow`, settings tiles, search tag chips, Kurumi post context menus and download menus; avoid duplicate wrappers unless real consumers justify them.

Treat these as confirmed **source observations**, not reproduced visual bugs. Re-check actual lines after any branch updates. Avoid reopening completed #50 (labels/icons) and #130 (adaptive titles) without a distinct regression.

## Screenshot and UX pass

Follow the capture matrix in `docs/designs/2026-11-02-ui-design-system-audit.md` and the review prompt. Capture **this fork**, not upstream or marketplace images. Record commit, platform, viewport, theme, text scale, active profile/engine, interaction state and sanitized screenshot filename. Review search, post grid/viewer, bookmarks, Following Topics, settings, download manager, profile configuration and representative engine-specific details.

Use Android emulators only if needed and only after reading `docs/android_emulator.md` and acquiring the required exclusive lease; use Maestro and real, existing test scenarios. Do not expose test-account details or private content in commits, handoffs, screenshots or Penpot. Where practical, verify narrow width, keyboard-open UI, enlarged text, and desktop focus/hover. If screenshots or a device are not accessible, mark visual claims unverified.

Use the read-only three-cycle UX-review prompt to obtain an independent assessment, then counter-review each finding against source and screenshots. Findings must distinguish source-only, screenshot-confirmed and device-reproduced evidence. Prioritize by user impact, risk and implementation cost, without sacrificing compactness or performance. Existing GitHub issues are the sole issue tracker: check duplicates before creating follow-up issues.

## Design-system and Penpot next steps

- Refine `docs/ui_style_guide.md` into concise, actionable component-selection and interaction rules. Keep it **proposed** until the resulting UX decisions are accepted. Verify color roles across light, dark, AMOLED, dynamic and profile themes; document meaningful exceptions, not arbitrary universal pixel sizes.
- Reconcile decisions with the existing public Kurumi API (`packages/kurumi/lib/kurumi.dart`), app wrappers, tests and existing screen conventions. Shared visual primitives belong in Kurumi; app- or engine-policy does not.
- If a Penpot workspace, compatible MCP client and edit access are actually available, begin with approved components, semantic color modes and a few representative screens. Link each to Dart implementations and reviewed fork screenshots. Do not claim a live Penpot library exists until verified. If access is absent, keep the proposal and report the blocker.
- Do not require a 1:1 design for every site, state, theme, width or locale. Code/tests own running behavior; reviewed Penpot references own approved target visuals. Avoid unmaintainable pixel-perfect CI.
- Significant visual or interaction changes require product-owner review before large-scale implementation. Prefer focused UI changes or separate issues over a repo-wide refactor.

## Verification performed before this handoff

- **Passed:** `python3 -m unittest discover -s scripts/tests -p 'test_audit_ui_components.py' -v` — 4 tests in the prepared patch tree.
- **Passed:** Python bytecode compilation of the scanner and its tests (`python3 -m compileall -q`).
- **Checked:** seven new-file patch entries have expected line counts and no content truncation.
- **Not performed:** full local Boorusama-tree scanner run, app Flutter tests, Android/desktop UI, screenshot review, external UX expert pass or Penpot workspace creation.

These checks cover only the prepared artifacts. Re-run from the actual checked-out branch and document results. Before any authorized integration into `develop`, the **final combined candidate** must pass the complete suite defined by `AGENTS.md` and `docs/engineering_guidelines.md`. Doc-only local changes need only relevant checks; adding scripts requires their tooling tests.

## Completion and handoff back

Commit verified findings and revised docs on this same branch with clear source evidence. Report actual branch/commit, changed files, scanner output location, observed screenshots/UX findings, performed tests, unresolved visual/product decisions and any Penpot access limitation. Do not create a PR or integrate/push `develop` without explicit approval. Leave Issue #136 open while the agreed UX review/design baseline is incomplete.
