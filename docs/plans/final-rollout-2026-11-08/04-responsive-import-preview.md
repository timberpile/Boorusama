# Plan 04: responsive large-export import review

Read the [lead handoff](../../handoffs/final-rollout-remediation-2026-11-08.md). This is a correctness/performance regression in the existing #142/#155/#158 import pipeline, not a new import system. Preserve the transaction, recovery, schema and profile-independent Bookmark contracts.

## Report and confirmed mechanism

The user reports more than ten seconds of freezing and occasional crashes when changing an import category from Custom to Replace, and even when checking 'I understand', with an approximately 3 MB export. File size alone does not describe the workload; record counts, memberships, hierarchy, Topics and local data size matter.

Source at `4b9e8f6f9fbdd5020e1de87942f4b8a5f683ba5d` confirms that `ImportFlowNotifier.acknowledgeWarnings` invokes `_profileDependencies(resolved)` and `_preflightWithDependencies(...)` synchronously. `replaceSource` and `chooseProfileMapping` do the same. `_preflightWithDependencies` calls `plannedChanges` for every source snapshot. The Bookmark projector rebuilds hierarchy/projection data, and the review page eagerly constructs substantial selection/preview content.

This proves avoidable repeated work on the UI path. It does not establish the exact duration or whether the user's crash is ANR, memory exhaustion, stack overflow, an exception, or process termination. Obtain distinguishing evidence before assigning a crash cause.

Relevant files:

- `lib/core/backups/export_import/import/import_flow_notifier.dart`
- `import_preflight.dart`, `profile_dependency_planner.dart`, `bookmark_profile_dependency.dart`
- `import_planned_change_projector.dart`, `import_item_labels.dart`
- `lib/core/backups/sources/bookmark_unified_import.dart`, backup data/codec and import planner/service
- `lib/core/backups/export_import/import/import_flow_page.dart`
- `lib/core/backups/export_import/widgets/import_action_editor.dart`, `import_change_preview.dart`, selection-tree consumers

## 1. Reproduce and measure before broad changes

Use a sanitized representative package around the reported size with many Posts, nested Groups, repeated memberships, Topics and Profiles, plus a nonempty local library. Also exercise the user's actual package locally if available and authorized, without committing its contents or logging private values.

Measure initial staging/parsing, local snapshot acquisition, dependency calculation, each source projection, diff/summary generation, widget building, acknowledgement, and final application separately. Capture Android logcat/error/ANR evidence and memory peaks. Distinguish debug-emulator overhead from profile/release behavior; compare the same candidate inputs and device configuration before/after.

Add counters/completion boundaries to deterministic tests so expensive-operation regressions can be asserted without brittle millisecond limits. Do not rely on an arbitrary sleep, a longer test timeout, or a spinner to prove responsiveness.

## 2. Make acknowledgement a cheap state change

The acknowledgement checkbox does not change imported content, target mappings, hierarchy or the planned mutations.

- Reuse the existing computed plan, dependency result, source summaries and warnings.
- Update only the acknowledgement/validation gate and the dependent button/checkbox state. Do not call the expensive projector, re-read snapshots, parse package data, rehash a database or rebuild the whole change model.
- Acknowledgement must correspond to the current plan/warning revision. A new destructive choice or changed warning set invalidates it according to the existing confirmation contract. Never let acknowledgement of an older preview authorize a newer Replace operation.
- Apply must continue validating captured source revisions and all preflight conditions. This optimization is not permission to bypass preflight or transaction safety.

**Key regression:** after the initial preview is ready, toggle acknowledgement repeatedly and assert zero new dependency/projection/staging calls. The checkbox must update without a long synchronous stall.

## 3. Recompute only affected plans

Preparation already owns a staged package and local source snapshots. Retain and reuse those immutable prepared facts for the review session rather than reconstructing them on every UI event.

1. Build stable lookup indexes for source identities, record IDs, hierarchy and membership once per relevant input revision. Avoid repeated per-record whole-list searches or full snapshot encode/decode merely to count changes.
2. Recompute the changed source and its real dependents only. A Bookmark action change must not regenerate unrelated Topic/setting previews; a Profile mapping change may invalidate the dependent Bookmark/Following portions. Explicitly model these few existing dependencies rather than add a generic incremental-computation framework.
3. Keep caching bounded to the current review session and current/most-recent effective plan. Do not retain complete projected libraries for every possible action combination. Reuse immutable references for unchanged summaries and item labels.
4. Preserve the same semantic planning code for preview and apply. A cheaper preview must not silently estimate different removals or identities. Exact counts and safety validation remain correct; detailed per-row presentation may be computed lazily.
5. Collapse equivalent rapid input changes into the latest requested generation. A late result from an older Custom/Replace choice cannot overwrite the newer preview.

Use existing state where possible. If asynchronous planning needs explicit internal state, a minimal proposal is:

```text
planningRevision: int                    // monotonically increases for content/mapping choices
previewPending: bool                     // new planning work exists; Apply is disabled
warningsAcknowledgedForRevision?: int    // acknowledgement belongs to exactly one completed revision
```

These are transient review-session fields, not backup schema or another persisted task model. Existing captured source revision tokens remain authoritative for stale-data validation.

## 4. Keep expensive pure work off the UI isolate

After removing redundant work, move the measured CPU-heavy pure projection/diff stages to the existing supported worker/isolate pattern, or bounded incremental work if measurements justify it.

- Transfer plain validated data, not Riverpod refs, BuildContext, Hive boxes, live clients or callbacks.
- Account for serialization/copy cost and memory pressure. One retained prepared representation and compact summaries are preferable to repeated large deep copies.
- Do not wrap the same synchronous computation in `Future(...)` or a microtask and call that an off-thread fix.
- A generation/lifecycle guard discards old results after another edit, Back, package replacement or disposal. Cancel work cooperatively where practical; never publish to a disposed notifier.
- Keep the last complete preview visible with a localized updating state while a new preview is prepared. Disable Apply until the displayed plan and selected choices match.
- Do not dispose staging files while an apply/owned reader still needs them. Reuse existing ownership and transaction rules.

## 5. Make large review surfaces lazy

Inspect the actual layout rather than merely changing the controller. Collapsed categories must not eagerly build every item/detail row. Use the existing lazy list/tree patterns with stable IDs and finite viewport constraints; avoid nested shrink-wrapped lists that measure all rows.

Show exact summary counts immediately, and reveal details on expansion without allocating every rendered row up front. Reuse unchanged presentations. Replace quadratic name-disambiguation scans with a counted lookup where relevant, but prioritize measured dominant costs.

The selected action and acknowledgement should be visible immediately. Preserve search, expansion and scroll state while an unrelated category changes.

## 6. Correctness and acceptance

Automated cases must include:

- Initial large-package load; repeated acknowledgement with no replanning; changing one source invalidates only its dependency set.
- Rapid Custom/Replace/Skip and profile mapping changes with controlled out-of-order completions; correct latest preview and Apply gate.
- Destructive warnings changed after acknowledgement; Apply rechecks current revision and cannot use stale consent.
- Profiles omitted from a Bookmark import; unresolved required Following profiles remain distinct from optional Bookmark hints.
- Merge/copy/replace, overlap memberships, nested hierarchy, large repeated records, unknown future payload retention and supported historical backup formats.
- Back/disposal/reload during work, worker error, disk-write error, out-of-memory-safe bounded behavior where testable, and no partial import.
- Existing transaction failure/rollback/restart recovery and preview/apply equivalence. Do not remove old durability tests to simplify optimization.

On Android, repeatedly change Bookmarks, Topics and Profiles between Custom and Replace, toggle acknowledgement, expand large categories and cancel. Capture time to the next responsive frame, total preview completion and memory separately. A small checkbox operation must not invoke large work; sustained multi-second unresponsive frames or crashes are unacceptable. Report actual measured improvement and remaining costs, not a universal hardware-independent speed promise.

Run all affected backup/import and Bookmark/Following consumers, appropriate package suites, analysis and the final combined regression. Retain any original crash reproduction and the before/after evidence in durable local artifacts.
