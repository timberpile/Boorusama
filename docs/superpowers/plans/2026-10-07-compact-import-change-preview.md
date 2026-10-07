# Compact import change preview implementation plan

**Goal:** Implement the approved DATA-015 mockup as a compact, accurate review of the resolved import before writes.

**Architecture:** Keep existing executor-aware local/projected collection maps and validation summaries; attach immutable display rows to those summaries. Display counts derive from those rows rather than storage entities, so memberships and group entities count consistently and feed internal searches do not duplicate feed changes. Generic sources use their current executor semantics: settings and global tag lists replace, SQLite gets an explicit opaque database-replacement limitation.

**Spec:** [DATA-015](../../work/in-progress/DATA-015-compact-import-change-preview.md) and [approved mockup](../mockups/2026-10-05-compact-import-change-preview.html).

**Constraints:** Same ticket/worktree; fvm; localize user-facing text; all secret display values masked in projection; no mutation before confirmation; existing transaction/revision protection preserved; no commit/integration/publication/device use without coordinator allocation.

**Files:** New `import/import_change_preview.dart` (immutable display rows/counts and safe field diffs) and `widgets/import_change_preview.dart` (compact disclosures). Extend `import/import_preflight.dart` and `import/import_planned_change_projector.dart` to carry rows generated from exact projected state; connect generic typed source projections in `import/import_flow_notifier.dart`; replace verbose block in `import/import_flow_page.dart`. Update `packages/i18n/translations/en-US.json`, `de-DE.json` and generated localization outputs. Focused tests in `test/core/backups/export_import/` cover projector, preflight, widget and flow behavior.

## One cohesive deliverable: resolved preview through review confirmation

- [x] Add failing observable projector tests for membership-only Update (no extra changed group), true rename, create/remove groups, shared memberships, ungrouped/metadata mutation, skip/identical; folders/feeds/profiles actions and mapping; settings concrete keys, global/scoped blacklist rules, nested secrets and opaque SQLite limits.
- [x] Run new tests with `fvm flutter test test/core/backups/export_import/import_planned_change_projector_test.dart`; confirm failures before product edits.
- [x] Add immutable `ImportChangePreviewRow`/detail/count models; reuse existing local/projected maps in `_summarize` to produce changed rows. Preserve existing `PlannedChangeSummary` validation counts and revision tokens. Bookmark membership-only row contributes membership subtotals; true group rename contributes one changed group; feed detail fields explain a single feed change. Profile scoped blacklist is expanded detail on the profile row and contributes no second entity count. Ungrouped/bookmark metadata changes get honest compact separate rows.
- [x] Add typed scalar/settings/replace-list/opaque database projections following the inspected current executors; sanitize nested auth/header/credential URLs before values reach widgets. Recompute rows whenever action/profile mapping changes.
- [x] Replace verbose review summaries with `ImportChangePreview` accepting source summaries and localized category/profile names; overall and category disclosures collapsed initially, independently toggleable, counts always visible, details optional. No unchanged/skipped rows. No-op text and existing Import validation remain accurate.
- [x] Add observable widget tests at 280px and enlarged text, independent disclosure/count visibility, details masking, cancellation/no mutation, selection/mapping recomputation and stale local revision requiring renewed review/confirmation. Refresh the proposed plan when stale without automatically applying it.
- [x] Regenerate i18n via CLI setup plus `./gen.sh i18n`, format changed Dart, run focused projector/preflight/widget/flow and source-executor regressions, analyze affected scope, inspect final diff. Expand checks only for a concrete coverage gap.
- [x] Update ticket/documentation and `/tmp/data015-product-report.md` with evidence and limitations; present dirty branch result to coordinator. Do not mark done until all criteria verified.

## Review focus

Identity differs from display name; Replace deletes absent local entities; local-only shared memberships survive merge and partial skips; identical credentials-free profiles remain no-op; arbitrary nested auth/header/URL values remain masked. Test these in the cohesive deliverable alongside narrow/large-text UI, stable stale-plan reconfirmation and explicit SQLite limits.

## Final verification · 2026-10-07

Implemented and independently reviewed without blocking findings. Focused suite: 74 tests passed; mechanical lint correction rerun: 39 passed; final projector/expanded-details widgets: 34 passed. Scoped analysis has no errors or warnings and 23 informational style lints. Evidence and practical limits: `/tmp/data015-product-report.md`. Ticket stays in-progress and review-ready pending local user review/integration; no commit or publication.
