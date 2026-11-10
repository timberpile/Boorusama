# P5 import dialog feedback — 2026-11-10

Completed implementation branch: `feature/142-profile-independent-import-package`.
Approved source: `cceb6cba6e2b86c3b618f05fdc75604037384454`.
Verified integration candidate: `3aa295d2758cf856410d8576c5d28df1b3bed861`.
Checked tree: `f08ed60e100d23760140d6973e4335d0ca2032b9`.
The final integration report update changes documentation only; runtime, tests,
localization inputs and generated runtime output remain equivalent to this pass.
Accepted P4 parent remains `42dbdb6afe6066d54ecfdcb70543031c12ca2585`.
This follows the [earlier P5 qualification](142-profile-independent-import-current-develop-2026-11-10.md).

## Owner feedback and scope

The owner accepted self-export/import changing only the last backup date. Do not
request another acceptance test for unchanged self-copy behavior. The reported
freezes affect options inside the import dialog, rather than global app settings.

The source-picker defect is fixed for portable imported records. Media access
without a usable profile remains P6 (#143); P5 still retains those records while
ordinary grids/covers omit unavailable media. Public/offline readers and native
Group activation were not added to this package.

P5 includes the owner's required timeline-toolbar indicator, so successfully
imported Posts cannot disappear without an explanation. The toolbar shows a
localized unavailable-Post total; its Kurumi popup lists websites and counts and
identifies the missing matching profile. Counts reflect the current group
or subtree, source and positive/negative tags, deduplicate shared memberships,
and update on profile changes. The indicator remains visible when ordinary
Bookmark counts are disabled. It counts saved Posts, not individual remote Pool
members or native Group records. The existing Combined indicator, pinned toolbar
slot and cache pattern were reused and adapted without P6 reader dependencies.
Anonymous/public viewing stays in P6; later availability projections will remove
viewable Posts from this count. Ownership is recorded in the
[sequential integration plan](../plans/2026-11-09-sequential-integration.md).

The owner confirmed the required-profile message occurred while Topics/Feeds
were also selected. Their dependency remains valid; pure Bookmark imports still
have no required profile dependency. At the owner's request, both missing-profile
and ambiguous-profile messages now use concise English and German text naming
the website and affected categories, for example
`<site>: Profile required to import Topics.`

## Confirmed causes and changes

- Equatable's nested membership-set comparison made populated self-Replace
  projection quadratic. Hash-based set/map comparison preserves all membership
  fields and dates, including reversed membership order and an actual date edit.
- Pure Bookmark decoding, local recovery/revision encoding and source projection
  now run in detached isolates. Provider-backed codec lookups resolve before
  crossing that boundary; validation, repository access and execution remain on
  the caller. Cold Bookmark admission and P5's exact opaque self-Replace matching
  remain intact.
- Unchanged projections are reused. Warning consent gates cached validation
  without recomputing the library. Pending previews disable Apply/consent; rapid
  option changes coalesce and only the latest revision publishes. A failed new
  preview cannot revive earlier validation through warning acknowledgement or
  reuse an older projection after a failed codec lookup. Disposal,
  staging, disk-capacity and late snapshot continuations are guarded.
- Collapsed preview sections previously constructed all detail widgets. They
  now defer those subtrees; large expanded lists use bounded builder viewports.
  Counts still include every entry and expansion state survives remounting.
- Portable transfer omits local-only `sourceUrl`. The source choices, listing
  filter and autocomplete now fall back to the stored origin host and omit empty
  choices, without depending on installed profiles. Existing nonempty local
  source URLs keep their established precedence.

The unavailable-count projection shares the listing's source/tag matcher but
avoids sorting/shuffling. Its toolbar cache keys use availability identity rather
than deep library equality, preventing membership-only changes from repeating
nested set comparisons.

The relevant performance changes were extracted from the Combined reference,
without merging that branch or its later packages. Independent review found
missing load-continuation guards; these were corrected and covered by a
completion-controlled stale snapshot regression.

## Verification

`./scripts/run_regression_tests.sh` completed with exit zero on exact final
integration candidate `3aa295d275`, based on current `origin/develop` parent
`42dbdb6afe`: **6,659 application tests**, **1,677 package/CLI tests across all
13 roots**, **both repository shell suites**, and **76 Python tests** passed.
Two existing individual package test skips remain; no complete root was skipped.
The default concurrency was the detected six physical cores. This complete pass
includes the final removal of the saved/exported notice.

Independent GPT-6.1 Sol, High effort reviewed the exact source, final notice
removal and tree equivalence. The preceding complete gate on `066599baa3` was
independently reconciled as **APPROVE SOURCE**, with no remaining confirmed
blockers; final integration evidence is retained beside that source review.
Confirmed continuation, consent/cache and toolbar equality findings were fixed.

The owner accepted the final copy and explicitly chose to keep the title
`Unavailable posts`. The saved/exported notice remains removed. Integration,
publication, issue closure and completed task cleanup are authorized after the
successful gate. P6 implementation is authorized after P5 publication, on the
accepted develop base; P6 integration remains separate.

Focused toolbar/listing/profile checks passed 58 cases across all nine affected
files. Additional checks passed: 26 lifecycle/layout checks, six complete AnimeBoxes
migration-contract checks, and 21 source/self-Replace/cache checks. The pending
preview test exercises 320px width, doubled text and a 240px keyboard inset; the
large preview regression retains all 5,000 rows while bounding visible widgets.
Final consent-failure/recovery checks passed 32 cases, and the concise-message
consumer checks passed 24 cases. Older failed and interrupted draft runs remain
in the artifacts and are not passes. Migration UI fixtures await actual background completion outside the
widget test's fake clock; their original dropdown, target and storage assertions
remain.

Committed-scope analysis of all 36 changed Dart files exited zero: zero errors,
zero warnings and 68 informational findings. Changed Dart files were formatted with
FVM; `git diff --check` passed. `./gen.sh i18n` validated the English/German localization inputs and regenerated
the required ignored output successfully.

The opt-in serial host workload uses production v10 transfer encode/decode and
5,000 incoming records. Before the fix, projection took 371,838us with no local
records and 33,639,469us with 5,000 local records. On final runtime code it took
345,774us and 934,771us respectively (on the unchanged projector implementation), with zero created/updated/deleted entities
for self-Replace. These are host projection timings, not Android frame or
end-to-end dialog timings.

No new APK, Android/Maestro campaign, device responsiveness measurement or live
service test was performed for this feedback candidate. Earlier native evidence
in the linked qualification applies to `4695c0794`, not this revision. The owner
builds review APKs personally. No PR or release is requested. No new device
responsiveness or live-service acceptance is inferred from the host pass.

Owner checks for changed behavior: open a large import and change its options;
review the shorter Topic/Feed profile messages; after a missing-profile import,
check the timeline's unavailable total/site breakdown and its response to group,
source/tag filters and matching profile restoration. Do not repeat the already
accepted unchanged self-export/last-backup-date check.

Final approved-integration evidence is in
`.worktrees/_artifacts/p5-approved-integration-20261110/` (`candidate.json`,
`regression.log/.exit`, and the final publication report). Earlier feedback
artifacts remain historical evidence.

Durable feedback evidence: `.worktrees/_artifacts/p5-import-feedback-20261110/`:
`regression-final.log/.exit`, `analysis-with-toolbar.log/.exit`,
`source-review.md`, `copy-removal.log/.exit`, `i18n-copy-removal.log/.exit`,
`analysis-copy-removal.log/.exit`,
`toolbar-final.log/.exit`, `i18n-toolbar-final.log/.exit`,
`consent-final.log/.exit`, `messages-final.log/.exit`, `i18n-feedback.log/.exit`,
`cleanup-layout.log/.exit`, `migration-final2.log/.exit`, `cache-source.log/.exit`,
`preview-before.log/.exit`, `preview-final.log/.exit`, and `final-candidate.txt`.
