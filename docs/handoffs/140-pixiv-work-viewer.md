# Issue #140: native Pixiv Works in the shared Viewer

Branch: `feature/140-pixiv-work-viewer` in `.worktrees/140-pixiv-work-viewer`.
Base: `22348b2fb20049088705ce38f5b261e191b148af` (`develop`, accepted #164).
Status: the owner authorized #140 integration after the complete local suite passes. The final runtime/test candidate is `03c6f97d07cb270b15be271db3187f3874e32ca1`, including the short-swipe correction below. Its complete local regression passed: 7,105 application tests, 1,693 package/CLI tests, both shell suites and 76 Python tests. Android/live-service evidence remains separate. No publication or integration is claimed by this update.

## Resulting behavior

Native Browse, Search (including artist queries), Ranking, Following, Recommended
and Favorites display one artwork per card. Illustration/manga cards use genuine
Work references; Ugoira stays on the existing real animation Post path. Each
endpoint retains its query, ordering and pagination. Favorites retains account/
privacy cursor ownership and bounded automatic continuation, failure/retry and
refresh behavior. Existing Post-only repositories and Following Topics snapshots
retain their explicit compatibility projection.

The Work image region supplies an inner Page pager to #164's shared outer Viewer.
The accepted Immersive/Details modes, finger-following transition, snap animation,
system insets, overlay and Back behavior remain owned by that shared Viewer.
Swiping anywhere in the media frame, including black margins, changes Pages.
Swiping Details content changes outer Works. At a Work's first/last Page, a new
outward swipe reaches the previous/next outer Post or Work. A gesture starting
within a Work moves only its Page pager, even when it reaches the boundary.
Media arrows and page-level keyboard navigation follow the same Page/entry
boundary rule, while Details retains outer navigation. A loading/restoring Page
manifest or a not-yet-mounted media pager does not prove a Work boundary, so a
fast swipe cannot advance the outer sequence during that preparation. Terminal
unavailable Works remain escapable.

Reading checkpoints, Page selection and image transforms belong to each outer
occurrence. Repeated copies of a Work therefore have independent reading state.
Only the current occurrence and up to two preceding/following entries retain
Page selection, visited state, transforms and Details scroll. Leaving that
window resets distant returns to the first or explicitly requested initial Page,
top scroll and contain-fit zoom. This does not expand the preload window.
Original source indices and missing/restricted Page slots are retained. Loading,
source loss and unavailable slots expose no neighboring Page action. Work
metadata remains on Details; it is not copied into Page facts.

The selected real Page now uses the ordinary engine Post presentation: its
standard toolbar, tags, file details, quality controls, downloads and media
sharing. The toolbar and image use the same Page controller. Work commentary
uses the existing Artist section; there is no separate Work toolbar or Details
layout. The standard toolbar's overflow adds Work link sharing and Download all.
Download all prepares a bounded manifest (at most 5,000 slots / 128 batches),
queues available Pages through the existing downloader, reports incomplete
preparation and supports cancellation. Names and Page links use original source
Page identities. The existing Group link action shares the Work reference.
Toolbar actions and media both carry the captured content access scope.
Local whole-Work Bookmark actions remain capability-gated until #141.

A subtle, noninteractive top-right reading hint shows the original Page position
and total, including unavailable slots. It appears on entry and Page changes,
fades after three idle seconds, and never enables the viewer overlay or Android
chrome. In hidden Immersive it sits four pixels from the screen top without
reserving the hidden Android status-bar inset. A Work or Collection with fewer
than two known images omits its thumbnail count badge. In Details, the entire media frame, including black letterboxing,
returns to Immersive on tap. A short vertical release still in motion completes
the mode transition using the final direction; stationary releases retain the
distance threshold, and reversing the movement can cancel the switch. Existing
media gestures and overlay controls retain their own interaction handlers.

Each Page fits independently within a full-width media pager. Works retain a
stable Details media frame, capped at the existing 60-percent safe-height limit;
the cover cannot scale or clip the entire carousel. Accepted, uncropped display
and original decodes correct Pixiv's cover-derived Page geometry. Cropped grid
previews never replace that geometry. The Details reading hint sits directly
below the Android status bar, while the immersive overlay still reserves its
Info control's hit area.

Pixiv's square timeline thumbnails are cropped. The Work Viewer now uses only
known full-aspect `large`/`medium` samples during metadata and media preparation;
those samples continue through the real Page's progressive-image pipeline.
Missing or restored non-cover Pages never borrow another Page's preview.

Mobile Viewer entry uses a consistent side slide with a first-frame paint guard.
The earlier thumbnail-growth prototype is retired: production cards put their
image below an input/ink layer, so its pointer-based capture did not run there;
the previous synthetic source widget failed to exercise that boundary. Closing
always moves down. A dismissal drag has no horizontal translation or scaling,
and its current vertical offset survives release while the route continues down.
Cancelled or non-closing actions return the image to its resting position.
Application/system reduced-motion behavior and the desktop fade are retained.

Adjacent Works and inner Pages prepare image widgets within the bounded viewport
cache before selection, so they can paint during the first half of a swipe.
Inactive Pages request known samples only, including when Original quality is
selected. Their controllers are leased by mounted Page consumers, preventing a
presentation rebuild from disposing a controller still used by another subtree.
The existing bounded metadata/media preloader retains its source, actor, cache,
loading-preference and non-speculative-original boundaries.

## Significant implementation boundaries

- The existing engine registry owns one captured Pixiv Work source per content
  access key. `pixivWorkSourceProvider` is an accessor to that source, with no
  second source lifetime or competing cache.
- Summary, Details and Pages share the existing bounded envelope cache. Native
  envelopes seed only complete Page manifests. If a list response omits its
  manifest, opening the Work performs its lazy detail request instead of
  manufacturing missing Pages or issuing one detail request per card.
- Native listing and direct Work reads apply the same captured rating/blacklist
  policy. Unknown tags cannot prove a configured blacklist is absent.
- The existing timeline prefetch logic now accepts a narrow continuation
  interface. Its Post behavior is unchanged; native timelines share its request
  budget, explicit-continuation reset, activity checks and error stop.
- Home/Search keep their existing search bars, announcements and profile flow.
  Optional native-result builders replace only the result projection.
- Per-occurrence Page preloading reuses the existing HTTP/cache and direction
  strategy with independent cancellation ownership. Speculation does not fetch
  originals. The existing media/zoom components render the real selected Post.
- No dependency, toolchain, persistence schema, backup version, shared Post model,
  remote Favorite mutation or Series implementation was added.

The retained architecture plan's old Image View/Overview wording is superseded
by accepted #164 Immersive/Details. The owner's explicit 2026-11-13 continuation
requests three independent Astra XHigh source reviewers; their actual execution
and re-review are recorded below.

## Short horizontal swipes over Details commentary (2026-11-13)

The owner reported that Details required a longer horizontal swipe than Immersive.
There is no separate mode-specific PageView threshold. A real ArtistSection
commentary reproduction found that its nested AppHtml SelectableRegion claimed
horizontal gestures before the pager. The same 80-logical-pixel fling at velocity
1200 passed in Immersive and failed over Details commentary, in both directions
for ordinary Posts and single-Page Works (four passes, four failures).

AppHtml can now join an explicitly supplied selection registrar. ArtistSection
uses the existing NativeMetadataSelectionScope above the outer pager, keeping
standalone HTML behavior intact. The existing pager wins ordinary touch swipes;
long-press selection still belongs to the native selection owner. No paging
physics, distance threshold, zoom, or media-gesture setting changed.

- Final focused matrix: **24 passed**, covering 400 x 800, 320 x 800 at 200 percent
  text, and 844 x 390; both modes, directions and Post/Work entries. Details cases
  also long-press the actual first commentary word, invoke Copy, and verify its
  platform clipboard payload. This uses the deterministic platform-channel test
  handler, not the host clipboard.
- Formatting passes for all four changed Dart files. Affected-file analysis:
  **0 errors, 1 existing warning, 10 informational findings**. The warning is the
  existing unused `coverUrl` test fixture variable. `git diff --check` passes.
- Evidence: `.worktrees/_artifacts/140-viewer-review-20261113/swipe-parity/`:
  `red.log/.exit`, `parity-final.log/.exit`, and `analysis-final.log/.exit`.
  The earlier 598-case affected run had 596 passes and two enlarged-text fixture
  failures: its midpoint targeted the second wrapped word. The final matrix uses
  RenderParagraph word boxes to select the intended word. An interrupted probe
  without a clipboard platform handler is retained as interrupted evidence.
- **Complete local regression passed** on `03c6f97d07cb270b15be271db3187f3874e32ca1`:
  **7,105 application tests**, **1,693 package/CLI tests across 13 roots**, both
  shell tooling suites and **76 Python tests**, exit zero. Two existing `go_router`
  skips remain. Command: `./scripts/run_regression_tests.sh`, detected physical-core
  concurrency six. Evidence: `swipe-parity/gate.commit`, `gate.log`, `gate.exit`.
  Only this handoff changed afterward; runtime/tests/dependencies/generated output
  match the tested candidate. The isolated squash integration must have the same
  complete tree as the task head, on the unchanged `22348b2fb...` develop parent.
- The independent reviews below inspected the previous retention/route candidate;
  this later, narrow selection-registration change was self-reviewed. The owner's
  prohibition on further Astra runs applies. Native Flutter checks do not establish
  Android gesture quality, platform clipboard integration, or live Pixiv behavior.

## Retention, snapshot and teardown qualification before swipe follow-up

Final runtime/test candidate: `803b64c480c7200a4798c4602a8d834e17c4541b`.
Runtime is unchanged from `bb32f5f895a7f4c5cda6464fefb840744324ff78`;
subsequent commits correct retained-route test selectors and the UI driver.
The fetched develop base remains `22348b2fb20049088705ce38f5b261e191b148af`.
Local evidence: `.worktrees/_artifacts/140-viewer-review-20261113/`.

- **R1 fixed:** retain interaction checkpoints only in the five-entry window.
  Drop distant selection associations after settlement; dispose a controller
  only after its last mounted media consumer detaches and no retained selection
  owns it. Keep overlapping/reparented media consumers and existing one-neighbor
  preparation. Guard late ordinary-Post transform/scroll writes, and disable
  PageStorage restoration for the inner pager and Details scroll so it cannot
  resurrect evicted state. No envelope/media-byte cache, stored Bookmark or
  source actor is invalidated by checkpoint eviction.
- **C1 reproduced and fixed:** same-actor, same-Page-identity hydration can publish
  new URLs/tags through Group members while the retained controller still owns
  the previous snapshot. Coalesce existing `replacePost` publication after build
  without replacing the controller or losing its Page/transform state. Group
  member hydration and explicit `GroupMembersController.refresh` can replace
  resolved snapshots; the controlled widget test isolates that contract and
  does not claim authenticated live Pixiv refresh acceptance.
- Diagnostic-only instrumentation of the reviewed `33f83c01a...` runtime makes
  all four new/updated regression cases fail: distant zoom survives, Work/Post
  state grows beyond five entries, and the controller retains old URLs/tags.
  The candidate was restored byte-for-byte afterward (`baseline-red.log/.exit`,
  `reproduce_baseline.py`). Traversal tests cover 24 repeated Work occurrences
  and 24 ordinary Posts, nearby Page/scroll/zoom restoration, clean distant
  returns, explicit initial member restoration, bounded controller lifetime,
  retained envelopes, metadata pending/failure, source loss with a held pointer
  and route teardown. Existing focused tests retain loading/restricted-slot,
  rapid reversal/fling, reparenting/overlap and mixed Post/Work/Pool coverage.
- **Additional confirmed P2 fixed during the complete gate:** deferred Viewer
  owner release reached a disposed navigation progress notifier. Mark the chrome
  controller dead and clear its owner before notifier disposal; ignore both late
  owner updates and route ticks. The direct regression fails before the guard
  (`chrome-red.log/.exit`). Preserve ordinary route-pop cleanup after the frame.
- Existing test assumptions were corrected without changing accepted behavior:
  wait on settlement/summary signals while a manifest spinner is pending; use the
  Details gutter rather than selectable HTML for an outer-swipe probe; assert
  that the mounted navigation bar excludes input/focus and follows reverse-route
  progress; scope Original retry RGB checks to the active Viewer, because its
  transparent route also retains the feed's decoded thumbnails.
- **473 requested focused tests passed** on `87af6c762`, including Details,
  pageview, preloading, Pools, Pixiv Works, native grid, navigation chrome and
  Following refresh lifecycle (`focused-final.log/.exit`). After the additional
  chrome fix, **126 navigation and real application-flow tests passed** on the
  final runtime candidate, covering route/input ownership, native menu metadata,
  search-viewer teardown and Original retry at 1x/2x (`chrome-green-final.log/.exit`).
- Formatting check: all 17 changed Dart files pass `fvm dart format
  --output=none --set-exit-if-changed`; `git diff --check` is clean. Final expanded
  affected-scope analysis has **0 errors, 6 existing warnings and 92 informational
  findings**, exit 2 (`analysis-final.log/.exit`). The warnings are four redundant
  non-null assertions in `media_group_page.dart`, the existing promoted cast in
  `mixed_post_details_page.dart`, and an unused `coverUrl` fixture variable.
- **Complete local regression passed** on `803b64c480c7200a4798c4602a8d834e17c4541b`:
  **7,081 application tests**, **1,693 package/CLI tests across 13 roots**, both
  repository shell suites and **76 Python tests**, exit zero. Two existing `go_router`
  skips remain. Command: `./scripts/run_regression_tests.sh`, physical-core
  concurrency six (`gate.commit`, `gate.log`, `gate.exit`). The final runtime,
  tests, dependencies and generated runtime output are unchanged by this handoff.
  Native finalizer diagnostics and existing nonfatal fixture tap warnings remain
  visible in the logs; this is a host assertion pass, not device stability proof.
  The first attempt on `87af6c762` was stopped after the confirmed chrome failure
  and stale test assumptions; its interrupted logs are historical evidence only
  (`gate-interrupted.log/.exit`, exit 143), not a complete pass. The next
  application inventory finished with 7,076 passing cases and five stale route
  assertions (`gate-route-inventory.log/.exit`, exit 1); it also is not a full
  pass. Their corrected source-link/gallery cases pass directly (five tests,
  `route-cases.log/.exit`), including actual UI Back and restored interactivity
  at both text scales. The shared test driver now reveals controls on the active
  scaffold rather than the retained, covered gallery.
- Three independent review tools were explicitly configured with
  `model=gpt-6-astra`, `reasoning_effort=xhigh`, `fork_turns=none`, with separate
  architecture/lifetime, gestures/routes/ordinary-Post, and media/actions/tests/
  #141 scopes. They inspected source independently and did not run competing
  tests or edit implementation files. Final re-review reports are
  `review-architecture.md`, `review-gestures.md`, and `review-media-actions.md`;
  all three re-reviewed `803b64c48` and report no remaining confirmed finding in
  their assigned scopes. They independently confirmed the chrome lifetime defect
  before re-reviewing its correction. Root-owned execution and independent source
  review are separate evidence.
- **Native Flutter renders:** the two opt-in capture tests pass on the same
  candidate (`native-renders.log/.exit`), producing 24 current-source frames
  under `native-renders/`. Four Details frames were inspected: Pixiv at 320px/2x
  and landscape, an ordinary portrait Post at 320px/2x, and an ordinary panoramic
  Post in landscape. Image frames and action rows remain within their viewport;
  scrolling/fading text follows the existing presentation. Command:
  `fvm flutter test --no-pub --dart-define=VIEWER_CAPTURE_DIR=<evidence>/native-renders
  test/core/posts/details/mixed_post_details_page_test.dart --name '^capture '
  --reporter expanded`. These renders do not replace Android service acceptance.
- **Android/live-service acceptance remains unfulfilled:** ADB discovery returned no devices, no
  local AVD was configured, and Maestro device discovery did not return. No
  emulator was operated, no settings changed and no APK was built. Narrow/text-
  enlarged and landscape widget coverage is host evidence; it does not prove
  Android animations, native Back, live CDN/API, video/Ugoira or native download/
  share acceptance. The owner directed use of native UI testing where possible. The current-source
  Flutter route, gesture, keyboard, Back and render tests provide the available
  UI evidence here. Android-only/live-service limits remain explicit; unavailable
  device/Maestro support does not hold up the authorized dependent local
  continuation after this host gate.
- **C2 remains a documented capability limit:** independently resolved members
  do not become actionable while optional Details is pending or failed. The
  controlled test records current fail-closed behavior. No speculative generic
  Gallery/source rewrite was included.

## Previous dismissal and entry review qualification (superseded)

Runtime/test commit: `f63bb5d25578a4f87638ef5e176b4db8a46f6d81`.
Evidence: `.worktrees/_artifacts/140-pixiv-works-20261112/review-dismiss-entry/`.

- Two focused regressions reproduced the old dismissal transform/reset and the
  missing neighboring Work image (`red.log/.exit`).
- **445 affected tests pass**, concurrency six, covering Details, pageview,
  progressive images, media preloading, Pools, Pixiv Works and native grids
  (`focused2.log/.exit`). This includes the existing portrait/narrow/landscape,
  RTL, pinch/pan and mode-transition tests; controlled pending-media preview,
  before-halfway painting in both directions and Original-quality safety; and
  a real PoolGridItem opening-frame/pixel test plus drag/release trajectory.
- Preparing neighboring Pages exposed shared-controller disposal during
  overlapping old/new media subtrees. Mounted-consumer ownership fixes that;
  the existing gesture/geometry matrices pass (`lifetime.log/.exit`).
- Two public CDN reads from the owner's supplied example confirm the square
  crop (540x540) versus the full sample (600x848); both images were inspected.
  These reads are not authenticated Work API or Android acceptance.
- Formatting: all 18 changed Dart files, zero changes; diff check clean.
  Final affected analysis reports zero errors, zero warnings and 21 existing
  informational style findings.
- Complete regression on `f63bb5d25578a4f87638ef5e176b4db8a46f6d81`: **7,059
  application tests**, **1,693 package/CLI tests across 13 roots**, both repository
  shell suites and **76 Python tests** pass, exit zero. Two existing Kurumi tests
  remain skipped. Command: `./scripts/run_regression_tests.sh`, physical-core
  concurrency six (`gate.commit`, `gate.log`, `gate.exit`).
- This qualification edit changes documentation only; the checked runtime,
  tests, dependencies and generated runtime output are unchanged.
- No APK build, emulator operation or remote account mutation was performed.
  Owner Android review remains necessary for real animation and CDN behavior.
  The requested checklist is short and inline, not another repository document.

## Previous geometry, loading and opening-transition qualification (superseded)

Runtime/test commit: `67dee198169551d095e6e9b402f84443d7340073`. The image/geometry implementation is
`e8ee54ca22117d4abd0cd1ce2b71fa3eb9f82078`; this final candidate additionally
preserves existing projection-level image-transition opt-outs.
Evidence is in `review-geometry-preload/` under the artifact directory below.

- **445 affected tests passed**, exit zero, at concurrency six:
  `fvm flutter test --no-pub --concurrency=6 test/core/posts/details
  test/core/posts/details_pageview test/core/posts/media_preload
  test/core/posts/pools test/boorus/pixiv/works test/core/content/native_content_grid_test.dart`.
- New tests cover independent portrait/square decoded Page geometry and
  full-width movement at 400, 320 and landscape widths, bounded adjacent Work
  and display-media preloading before navigation, disabled automatic loading,
  cached-cover handoff while metadata remains pending, and ignoring lower or
  superseded-rendition geometry.
- Actual route tests inspect intermediate thumbnail-growth frames, upper/lower
  chrome movement, side-entry fallback and downward-only closing. A real mixed
  Viewer test holds both the Work manifest and full image pending, checks the
  retained thumbnail's painted pixels during flight, releases the manifest
  mid-transition, and verifies the ordinary Page keeps the cached preview.
- The existing boundary, rapid-fling, RTL, pinch/pan, mode, missing-slot and
  source-scope tests also pass. Ordinary Post presentation remains on the same
  shared image pipeline.
- Nine host frames cover phone, narrow 200-percent text and landscape in all
  shared modes; four representative Details/overlay frames were inspected.
  Captures use the unchanged Viewer implementation from `e8ee54ca2`; the later
  boundary correction affects source-card eligibility only. These are host
  renders, not Android acceptance.
- Formatting: all 29 changed Dart files, zero changes; diff check clean.
  Affected runtime analysis: zero errors, zero warnings and 21 existing
  informational style findings in surrounding code.
- The initial complete run caught four projected-Pool Hero opt-out failures.
  Those existing tests now pass unchanged; native Group covers offer flights
  only for media-pager presentations. The superseded run was interrupted after
  those failures (`gate1.*`); its shutdown diagnostics are not a complete pass.
- Complete local regression on `67dee198169551d095e6e9b402f84443d7340073`:
  **7,059 application tests**, **1,693 package/CLI tests across 13 roots**, both
  repository shell suites and **76 Python tests** passed, exit zero. Two existing
  `go_router` tests remain skipped. Command: `./scripts/run_regression_tests.sh`,
  detected physical-core concurrency six. Evidence: `gate.commit`, `gate.log`,
  `gate.exit`. The host logs include native-shell finalizer diagnostics also
  present in the previous passing boundary gate; no tests or commands failed.
- This documentation-only qualification preserves the checked runtime, tests,
  dependencies and generated output. A changed develop integration candidate
  still requires verification of that resulting state.
- No APK, emulator interaction, live Pixiv request or remote mutation was
  performed. Owner Android review is still needed for visual feel, real CDN
  latency and playback/gesture integration.

## Previous fast-fling owner review qualification (superseded)

Runtime/test commit: `bfa6214b8d21261d39d9037689ca796d18fa8e43`.
Evidence is in `review-fast-flings/` under the artifact directory below.

- Controlled manifest completion reproduces the whole-Work skip before the fix
  in both directions (`red2.log/.exit`). Tests wait for the outer pager's actual
  settlement signal while deliberately keeping Page metadata pending.
- Three regressions verify pending manifests, fast repeated flings before inner
  Page settlement, traversal through every Page and real outer boundaries, and
  escape from a terminal manifest failure. No pending gesture is replayed after
  loading; navigation starts from the actual prepared Page.
- Scoped regression: **213 tests passed**, exit zero, using concurrency six:
  `fvm flutter test --no-pub --concurrency=6` with
  `test/core/posts/details/mixed_post_details_page_test.dart`,
  `test/core/posts/details_pageview`,
  `test/core/posts/details/media_group_page_indicator_test.dart`,
  `test/boorus/pixiv/works` and `test/core/content/native_content_grid_test.dart`.
  Evidence: `focused.log`, `focused.exit`, `focused.commit`.
- All three changed Dart files format without changes and analyze with no issues;
  `git diff --check` passes. The runtime change consists of readiness guards in
  the existing Work-only media navigation path; ordinary Post routing, layout,
  mode gestures, data models and persistence are unchanged.
- This is scoped local qualification for renewed owner review. The complete
  pre-integration suite must run on the final approved candidate; do not reuse
  the superseded full pass below for this changed runtime. No new APK, emulator,
  host captures, live Pixiv request or remote mutation was performed.

## Previous boundary gesture qualification (superseded)

Evidence is in `review-boundaries/` under the artifact directory below. The
previous complete pass is historical after these runtime changes.

- Twelve focused behavioral cases pass: full-frame Page/Work navigation in
  portrait, landscape and RTL; hidden-system-bar counter placement; and short,
  slow, paused and reversed releases in both directions between shared modes.
- The Work navigation matrix covers Details letterboxing, return to Immersive,
  finger-tracked outer boundaries, independent checkpoints, single-image Works,
  global entry boundaries, decoded-media pinch/return-to-fit and cancellation
  when a second pointer interrupts a Page drag.
- Media drag routing selects one PageController at gesture start and retains it
  until release. The existing toolbar drag surface shares that mechanism.
- Nine host frames were generated for phone, narrow 200-percent text and
  landscape in Immersive, complete overlay and Details. Representative modes
  were inspected, including the counter's top position and the normal footer.
  The harness disables the debug banner, matching the real application, and
  reveals the complete overlay with `showAllUI()`.
- Formatting: nine changed Dart files, zero changes; diff check clean.
- Final analysis of all nine changed Dart files: no issues found.
- Complete regression on runtime/test commit
  `b198ce93b3a484556c008981e3d57c61fbaf7438`:
  **7,044 application tests**, **1,693 package/CLI tests across 13 roots**, both
  repository shell suites and **76 Python tests** passed, exit zero. Two existing
  `go_router` tests remain skipped. Command: `./scripts/run_regression_tests.sh`,
  detected physical-core concurrency six. Evidence: `review-boundaries/gate.log`,
  `gate.exit`, `gate.commit`.
- This qualification update changes only documentation; the checked runtime,
  tests, dependencies and generated output remain identical. No Android or live
  Pixiv acceptance is claimed.

## Previous shared-presentation correction qualification (superseded)

Evidence is in `review-shared-viewer/` under the artifact directory below.
The earlier complete pass is historical and does not qualify the changed runtime.

- Normal Post toolbar, source binding and shared image-controller identity are
  checked on original Page 3; a missing Page exposes no neighboring actions.
- Inner Page gestures, outer Details swipes, ordinary Post controller settlement,
  repeated-Work restoration and finger-tracked mode transitions are covered at
  400 x 800, 320 x 844 at 200 percent text, and 844 x 390.
- The reading hint test uses the controlled widget clock to check idle expiry,
  timeout restart only on Page changes, pointer pass-through and safe disposal.
- Decoded portrait media reproduces the letterbox tap failure before the fix in
  both portrait and landscape; the same tests pass after the frame-level fix.
- Nine rendered Work frames cover Immersive, header overlay and Details at
  414 dp, 320 dp with enlarged text and landscape. All were inspected. These
  captures call `showOverlay()` for the header; live media taps use the existing
  `toggleOverlay()` path, which also shows the bottom toolbar. Standard toolbar
  presentation was inspected in Details. These are host renders, not Android or
  live-service acceptance.
- Final selected behavior/capture run: eight tests passed, exit zero. The final
  complete application suite also covers all 89 related viewer/badge tests.
- Formatting: 14 changed Dart files, zero changes; `git diff --check` passes.
- Final affected-file analysis: zero errors, zero warnings, nine informational
  findings (including unawaited animation futures in tests).
- Complete regression on runtime/test commit
  `1d9dc3433b200abd36d5690b11e02206585d649b`:
  **7,032 application tests**, **1,693 package/CLI tests across 13 roots**, both
  repository shell suites and **76 Python tests** passed, exit zero. Two existing
  `go_router` tests remain skipped. Evidence: `review-shared-viewer/gate.log`,
  `gate.exit`, `gate.commit`. Command: `./scripts/run_regression_tests.sh` with
  detected physical-core concurrency (six).
- This qualification update changes only documentation; the checked runtime,
  tests, dependencies and generated output remain identical.

The possible replacement of the immersive overlay with tap-to-Details remains
an owner triage discussion, including video-control ergonomics. It is not
implemented in this candidate; the accepted #164 overlay behavior is retained.

## Earlier candidate qualification (superseded)

Durable local logs are under the primary workspace's
`.worktrees/_artifacts/140-pixiv-works-20261111/` directory.

- Native entry-point tests: four passed, including normal Browse, empty Search,
  artist query and text query. Each proves one card per Work, Ugoira compatibility
  and no artwork-detail request from card construction.
- Shared Work viewer matrix: three passed (400 x 800, 320 x 844 at 200 percent
  text, and 844 x 390). It exercises Page swipes, a missing middle slot, disabled
  Page download, independent repeated-Work checkpoints, outer Details swipes,
  retained shared modes and source-bound toolbar actions.
- Favorites integration: eleven passed, covering actual client cursor dispatch,
  bounded range/continuation, retry, refresh, private/account changes, cancellation
  and narrow/enlarged-text/keyboard controls. The thumbnail-range probe proves
  HTTP dispatch timing; it does not establish live CDN decoding.
- Existing Explore header checks pass at 320 dp with normal and enlarged text.
  Only its timeline toolbar returns during reverse scrolling.
- Final formatting check: 42 changed Dart files, zero changes.
- Final affected-scope analysis: zero errors, zero warnings, 44 informational
  findings in existing surrounding code; new Work/native-media files are clean.
- Final complete regression on runtime commit
  `9adce4b87fd4e8b6a4e36c770ae425720e560857`:
  **7,028 application tests**, **1,693 package/CLI tests across 13 roots**, both
  repository shell suites and **76 Python tests** passed, exit zero.
  Evidence: `gate2.log`, `gate2.exit`, `gate2.commit`. The unchanged final
  implementation includes the native failure-text correction and its focused
  error/retry regression. Two existing `go_router` tests remain skipped.


No emulator, APK build, live Pixiv request or remote Favorite write was performed.
Owner Android review remains necessary for real CDN media, Page pinch/pan,
reading transitions, native download/share and account behavior. Host/widget
checks do not establish that device or service acceptance.

## Next dependent issue

#141 resumes after #140's final host gate passes, using native Flutter UI tests
where possible as directed by the owner. Its branch/worktree and all 33 existing
modified/untracked files were preserved unchanged, then checkpointed on the same
branch as `dabf4f8c3` before any replay.
Before any history operation, a temporary Git index created recovery commit
`95bdcb0d13257b52de60e1a67079d187881205ad` at
`refs/recovery/141-before-viewer-review-20261113`, parent
`f5808069673a381385286e1d94db0f874bbdeeb6`; the real index and working tree were
not changed. All 33 files were checked byte-for-byte against that snapshot.
The fetched remote #141 still points to `01fa085840f8442246505b1ad1d883e01a4fecdb`.
The genuine local #141-only committed delta starts after `9adce4b87...`; inspect
its preserved integration checkpoint as well as those three local commits
before a deliberate `rebase --onto`/semantic replay. Do not replay the old
cumulative prerequisite history or force-push.

Retain its existing branch identity and independent Work/Page targets, generic
picker/mutation session, memberships/Undo/backup semantics and portable links.
Its unfinished hooks in obsolete `media_group_details.dart` must move into the
current `MediaGroupActions` / `PostActionToolbarScope` / normal toolbar path;
do not revive a second Work toolbar. A draft's provisional ID must never select
a saved record, and saving a Work must not create Page bookmarks. Keep remote
Favorites separate. Preserve a separate final #141 handoff after combination
verification, then continue the agreed #144 and finally #157 sequence. Existing
package acceptance gates remain in force. The four #141-owned commits were
replayed onto `1cd076deb...` using an explicit
`rebase --onto`, preserving the recovery refs and branch identity. Obsolete
`media_group_details.dart` was removed instead of reviving its old toolbar.
The owner now requires the same owned delta to use published develop after #140
integration; do not inherit the old cumulative feature history.
The owner subsequently prohibited further Astra subagent runs unless
explicitly requested again; the completed three reviews above predate that
instruction. Do not reuse their model choice for later dependent work.
#140 is explicitly authorized for integration/publication after its final complete
gate. #141 remains local and must reach a separate owner-review boundary. Once
#141 is ready for review, continue #144 and then #157. Inspect existing feature
branches, handoffs, tests and approved designs first; the Combined branch is
reference material only and must never become a merge source.
