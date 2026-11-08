# Issue #140: Pixiv Work/Page viewer continuation

Status: **started, foundation reviewed, issue incomplete**. This branch begins
the authorized Pixiv work while #156 acceptance continues. No runtime UI cutover, publication,
PR, develop integration, issue closure or device acceptance is claimed.

Branch/worktree: `feature/140-pixiv-work-viewer`,
`.worktrees/140-pixiv-work-viewer`.
Base: `5a73ae6233d92abef4e7f062b35114743ed5d5a6` (#156 paused checkpoint).
That base includes unfinished #156 fixes and a cache design the user later
rejected. The #156 lead owns its replacement; do not import or duplicate that
cache/access work here. Reconcile the final prerequisite candidate before any
combined acceptance. Do not treat this branch as integration-ready.

## Existing UX and accepted target

The original issue description requests a comparison before selecting a UX.
There are no later issue comments. The approved architecture contract on the
planning reference branch records the later decision: Image View/Overview,
image-region swipes for Pages and details-region swipes for whole Works.
This comparison documents that established selection rather than assuming a
new decision or reopening it.

| Option | Current-code comparison | Outcome |
| --- | --- | --- |
| Work-level page gallery | Existing Pool/Related member grids provide scanning and explicit member opening, but moving into each Page loses an in-place reading sequence unless another media composition is introduced. | Useful comparison; not the approved default Work presentation. |
| Vertical reader | Existing Post viewer handles each real image's pan, zoom and quality, but there is no native continuous Pixiv reader. Introducing one would change scroll/gesture/preload ownership and needs a separate UX decision. | Not implemented or implicitly selected. |
| Work with individual Page navigation and Overview | The Mixed Viewer already retains outer occurrences and real Post media. The approved target keeps each Work as an outer entry, Pages as an inner media selection, and Overview on the same selected image. | Accepted contract; runtime composition remains to implement. |

The authoritative plan is `docs/plans/content-architecture/06-pixiv-viewer.md`
and `approved-contract.md` in the retained
`.worktrees/content-architecture-reference` checkout. Their old Astra reviewer
wording is superseded by the latest user instruction requiring Sol High.

## Started implementation

Pixiv-owned `works/work_mapper.dart` maps native artwork list responses to one
Group entry per illustration/manga without flattening Pages or fetching details.
Ugoira remains a genuine animation Post. It reuses deployed Work/Page key codecs,
Post parser, typed Pixiv data and synthetic compatibility IDs. Work captions
remain Work Details rather than being copied into Page detail facts.

`works/work_source.dart` supplies the existing ContentGroupSource contract over
one captured actor and the existing bounded GroupEnvelopeCache. Summary, Details
and members share a real artwork request. Native envelopes can seed it; refresh
rejects stale seeds. The Page manifest retains original zero-based slots and
unavailable members before projection. A later Page never receives an earlier
Page's key, media URL or download index. Cursor windows remain bounded and belong
to their exact source instance/Work/refresh generation.

`works/providers.dart` prepares the source with the current captured access key
and existing Pixiv client. It does not add a competing registry, account system,
shared Post type or fake Group Post. Group registration and actual listing/viewer
callers intentionally remain gated until the active-media composition exists.
This source foundation is not a complete delivery of #140.

## Remaining runtime and acceptance

- Connect actual ranking/search/Favorites/artist Work listings while preserving
  each native query/order/pagination behavior. Existing Post-only and Following
  callers remain on their explicit compatibility projection until connected.
- Add the approved occurrence-local active-media binding to the Mixed Viewer,
  clearing it on loading/error/grid state and outer occurrence changes. Coordinate
  edits with the #156 lead before touching common viewer/content files.
- Implement the approved Image View/Overview and gesture ownership, Page versus
  Work navigation, stable reading transforms and repeated Work checkpoints.
- Connect captured Page download/share and bounded Download All without remote
  Favorite mutations. Keep local whole-Work Bookmark actions capability-gated
  until #141 provides their real behavior.
- #141 must use its own branch after this Work/Page contract is stable; it remains
  a separate task and is not implemented in this branch.
- Run consumer and complete final-candidate regression, fresh independent actual
  Sol High review of the production integration, then real authenticated
  Android/Maestro acceptance with the required exclusive lease and verified
  restoration. No emulator is owned
  by this workstream.

## Verification

Fresh-worktree bootstrap used the pinned FVM SDK, dependency resolution and
`./gen.sh` only because generated manifests/localization/assets were absent.
No dependency or SDK upgrade is part of this task. Durable evidence lives in
`.worktrees/_artifacts/140-*` in the primary workspace.

- Final Work-foundation/parser command: `fvm flutter test --no-pub
  --concurrency=6 test/boorus/pixiv/works test/pixiv_test.dart` passed **59 tests**.
  Evidence: `140-work-final-candidate.log`. The six workers came from
  `python3 scripts/physical_core_count.py`.
- `fvm dart analyze lib/boorus/pixiv/works test/boorus/pixiv/works` reported no
  issues (zero errors, warnings or informational findings).
  Evidence: `140-work-final-candidate-analysis.log`.
- Changed Dart files are formatted; `git diff --check` passes.
- Initial scoped analysis caught missing origin/config extension imports; those
  were fixed. An intermediate provider-revocation fixture had unowned expected
  provider errors; the fixture now owns its listener's error, while retaining
  both late-result rejection and denied current-provider assertions.
- These checks cover only the new engine-owned foundation and its existing
  parser consumer. Full final-candidate regression, production integration review,
  device/live-Pixiv validation and actual viewer/listing integration remain open.
  No test count here implies completion of #140.

## Independent Sol High review correction

The independent foundation review identified one P2: the Pixiv DTO discarded
tag-field presence, so an omitted partial response published complete empty tags
and could erase cached tags/index facts. Focused regressions reproduced that
failure and a malformed native tag name throwing during DTO parsing. Evidence:
`140-tag-omission-reproduction.log` (two expected failures before correction).

The DTO now preserves unknown/partial/complete native tag observations without
changing its existing non-null list API. Missing/non-list fields stay unknown;
explicit `tags: []` remains authoritative empty; malformed entries retain usable
native names with partial coverage instead of throwing. The Work mapper emits
null when no usable fact was observed, preserving cached tags during the existing
Details merge, and marks valid malformed subsets partial. No common metadata,
authorization, storage or cache mechanism changed.

Final correction verification (same runtime/test candidate as this handoff):

- `fvm flutter test --no-pub --concurrency=6 test/boorus/pixiv/works
  test/pixiv_test.dart`: **61 passed**, `140-tag-omission-final-tests.log`.
- Complete `packages/booru_clients` suite, `fvm flutter test --no-pub
  --concurrency=6`: **240 passed**, `140-tag-omission-package-suite.log`.
- Analysis of Work source/tests and changed Pixiv DTO/test: **no issues** (zero
  errors, warnings or informational findings), `140-tag-omission-final-analysis.log`.
- Changed Dart formatting and `git diff --check` passed.

Independent actual Sol High review and re-review are complete for source candidate
`308463b1dcedf252ae260a361e13f6300244b9f5`. The reviewer independently reran the
foundation/parser command: **61 passed**, `sol-review-140-corrected-tests.log`.
The omitted/explicit-empty/partial-tag finding is resolved, with no remaining
actionable foundation findings. The [durable independent report](../../../_artifacts/architecture-foundations-sol-review.md)
records the exact scope, correction and limits; it is local workspace evidence,
not a published repository artifact.

This final handoff update changes documentation only. Runtime, tests and the
package subtree match the reviewed source candidate, so the existing scoped and
240-test package passes remain applicable. Documentation links and
`git diff --check` were verified without rerunning application tests.

Production listings, viewer composition/gestures/actions, full combined regression,
fresh production integration review and current Android/Maestro acceptance remain
open. The source foundation review does not complete #140 or authorize integration.
