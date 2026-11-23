# P7 with Pixiv prerequisite corrections

The owner requested local review and qualification of #165 and #161 with the
current P7 acceptance package. P1–P6 remain completed. This work does not resume
the separate audit, adopt its temporary workflows, or begin another package.

## Preserved sources and local candidate

- Published develop prerequisite: `2e2ea428ba323706e37a65e45903d3959df439d4`.
- P7 / #156: `maintenance/156-shared-source-groups-package`,
  `01c69f6bb7aae98f23ce7cd7d515b48ab5e078e5`.
- #165: `origin/bug/165-pixiv-media-loading`,
  `650b79fff19758031f0e5e08ce0350957756f48b`.
- #161: `origin/bug/161-pixiv-explore-pagination`,
  `22e52295dae2d75a7da878d63e617988dbd4d5b1`.
- Local qualification branch: `maintenance/p7-pixiv-qualification`,
  `.worktrees/p7-pixiv-qualification`, initial qualified runtime/test commit
  `b825d16b24a945345e866b9d81881df86b0d4157`, tree
  `9e0d80e5b78f12aea8e2276a6829cb41b87c610d`.

The candidate retains both issue histories in separate local merges onto P7.
Only the two owning branch deltas were included; their audit branch was read
as evidence. P7's existing source and all owning branches remain unchanged.
No code was published during initial qualification. The later integration
acceptance below supersedes the pending approval statements in this history.

## Reviewed behavior

#165 shares an exact public-root Referer decision across URL resolution and
transport redirect hops. Canonical HTTPS `pixiv.net/` may retain the existing
`https://www.pixiv.net/` header only for HTTPS/443 `i.pximg.net` and `s.pximg.net`.
This grants no source credential authority or general hostname normalization.
Explicit overrides, foreign hosts, account isolation and revocation remain guarded.
Image errors retain the original HTTP failure rather than converting it into
`Empty response`; retry policy and quiet candidate probes remain.

#161 reuses the existing continuation-preserving Pixiv conversion and removes the
repository's stale exhaustion cache. The grid controller owns the feed session,
explicit end signals, refresh, error retry and late-result admission.

Independent GPT-6.1 Sol High approved this exact source; no confirmed blocker
remains. Focused tests exercise actual production providers/adapters/fetcher and
controller with controlled server/completion fixtures. Source approval is separate
from owner acceptance and Android evidence.

## Local checks

- `./gen.sh` succeeded for missing generated outputs. `fvm flutter pub get --offline`
  generated the missing Android plugin registration for 35 plugins; dependency
  versions and tracked inputs were unchanged.
- Focused Pixiv media/diagnostics/pagination regression: 25 passed.
- Scoped `fvm flutter analyze --no-pub`: zero errors/warnings and eight
  informational findings (exit 1 due to those findings).
- Complete `./scripts/run_regression_tests.sh`, physical-core concurrency 6,
  exit 0: 6,924 application tests, 1,686 package/CLI tests across all 13 roots,
  both shell suites and 76 Python tests. Two existing GoRouter skips remain.
  The documented libavif directory-input warning did not interrupt the gate.
- Normal `lib/main.dart` dev-debug APK build succeeded. Build preparation exposed
  missing native plugin registration and a stale Gradle daemon spawn-helper
  failure. With registration generated, a fresh single-use process built the APK.
  When the owner reproduced the same failure with the normal run command, the
  one idle Gradle 8.14 daemon was stopped. A normal build then passed without
  the temporary environment override. No tracked Gradle/SDK/dependency change
  was required. The normal build has no `_artifacts` dependency.

The complete pass and APK result above apply to initial candidate `b825d16b24`.
They do not qualify the subsequent UI follow-up below. The changed combination
requires a new complete integration gate before publication to develop. APK
construction is not device acceptance.

## Owner device acceptance

Maestro MCP did not respond to device-list or static cheat-sheet requests. The
owner explicitly chose to perform the device checks personally. No current
candidate was installed or launched on the emulator, and no live Android Pixiv
request/decoding/continuation result is claimed.

Test this qualification worktree, rather than the unchanged develop or original
P7 worktree:

1. Browse fresh Pixiv results, scroll several screens, then open an image at
   Original quality. Thumbnails, preview and full image should load.
2. In Explore, load beyond the first page in Ranking, Following and Recommended
   where the account/feed has more results.
3. Refresh after pagination and continue loading; switch feed, ranking date/mode
   and public/private Following controls and check that their state stays separate.
4. Check image rendering in Following and remote Favorites.
5. Bookmark the exact Post whose Original was loaded, enable airplane mode,
   cold-start the app and reopen that saved image. Restore connectivity afterwards.

On failure, record the view, action and new HTTP/error diagnostic without account
credentials. Controlled empty/filtered pages, explicit terminal pages and late
responses have host coverage; owner device results remain pending.

The existing Phone1 emulator was started under an exclusive emulator-5554 lease.
Its stopped original APK/data were backed up in place. Before shutdown, normalized
archive comparison passed for all 1,108 entries with no missing/extra/changed data;
APK, stopped state, settings and window configuration also matched baseline.
No profile/token was used or rotated, no app data was moved/replaced, and no
candidate was installed. The owned emulator was stopped and its lease released.
The physical device was untouched.

## Owner feedback and UI follow-up

The owner reported that Pixiv images now load in Browse and Explore and that
the other checked behavior appears to work. Two additional UI requests followed:
only the timeline toolbar should return on reverse scrolling in Pixiv Explore,
and Following Topics feeds should show their currently loaded Post count. The
owner explicitly clarified that this count concerns Following Topics, not the
Following tab in Pixiv Explore.

The isolated issue-free branch `bug/explore-header-and-feed-count` retains these
changes separately from #165 and #161. Production fix `1b317bbba7a9ced497207a7e4104d2a495d90a28`
is followed by test-interaction corrections through `54ffcea04`. The updated
combined runtime/test candidate is `0435ce5d4487ec16636931e799fa4d491004ea1d`.

- The Explore title uses a nonfloating Kurumi sliver AppBar. Feed/mode/privacy
  controls use an ordinary sliver with natural height, so they scroll away and
  do not return with the independent timeline toolbar. The grid owns the top
  safe inset so the returning toolbar stays below the status bar. Natural sizing
  also removes the measured AppBar-bottom overflow found in the widget fixture.
- Following Topics uses its live PostScope controller's loaded total, including
  appended History and filtered projections. A listener keeps the label current;
  without a PostScope, the cached snapshot count is used. The existing localized
  counter and timeline typography are reused. Neither API totals nor only the
  original cached snapshot length substitute for the loaded controller total.
- The shared date selector uses the existing bounded Flexible-label pattern.
  This resolves the reproduced 147-pixel overflow at 320dp/2x text without
  changing date bounds or actions.

Verification on the updated combination: 109 targeted tests passed across the
affected Explore, Following Topics, timeline, media and pagination consumers.
Analysis of all six affected files reports no issues. Tests cover all three
Explore feeds at normal/2x text with actual scroll gestures and toolbar safe
insets; cached count 3, History count 4 and filtered count 0 with keyboard insets;
and sorting/History behavior at enlarged text. The existing sort test now taps
the visible portion of its potentially oversized horizontal control, rather than
an offscreen center. No test assertions about filtering or History were removed.

Independent GPT-6.1 Sol High approved the production source. The final change
after that source approval affects only the sort consumer test. The complete
`b825d16b24` pass remains historical; it is not a full pass for this UI combination.
Owner device checks for the two new UI behaviors remain pending. No emulator was
used for this follow-up. Evidence is retained in the ignored
`.worktrees/_artifacts/explore-header-feed-count-20261111/` directory.

## Sequential adoption at the initial handoff

Keep #165, #161 and P7 as separate issue-owned changes. Proposed adoption order is
#165, then #161, then P7/#156, preserving every issue ID in its integration subject.
The combined local candidate is for qualification; owner approval remains required
for develop integration/publication and issue closure. P7 remains the current
acceptance package. A different develop combination or runtime/test/dependency
change requires the appropriate new complete gate. An unchanged runtime candidate
does not require another suite for handoff-only changes.

Durable ignored evidence: `.worktrees/_artifacts/p7-pixiv-qualification-20261111/`.

## Final owner acceptance and integration

On 2026-11-11 the owner confirmed both UI follow-ups and approved integration
provided no further checks revealed a blocker. The earlier owner feedback also
confirmed Pixiv images in Browse and Explore and reported the other checked
behavior working. No further owner device retest of unchanged behavior is needed.
This is owner-reported acceptance; the agent did not perform new live Android
requests for the Pixiv fixes or the UI follow-up.

The final approved combination is qualified from test commit
`746f73f3726a3229f1b67405e9e0d1445a0f2108`, whose runtime/test tree is unchanged
from `0435ce5d4487ec16636931e799fa4d491004ea1d`. The local develop integration
keeps separate conventional squash commits:

- `b6f886b93`: Pixiv media loading and diagnostics, #165.
- `6a2dde51c`: Pixiv Explore continuation and refresh, #161.
- `5e8419c20`: existing remote source Groups, P7/#156.
- `ad13b68af`: the accepted Explore header and Following Topics loaded count.

Every non-documentation file matches the tested qualification candidate exactly.
The complete `./scripts/run_regression_tests.sh` pass on that exact candidate
used physical-core concurrency 6 and exited 0: 6,928 application tests, 1,686
package/CLI tests across all 13 roots, both repository shell suites and 76 Python
tests passed. Two existing GoRouter skips remain. No failed or interrupted check
is counted as a pass. Scoped analysis of the six UI files remains clean, and
independent approval of the unchanged production source and final targeted
evidence is retained. No new APK or emulator run was required for this integration.
Raw output is retained under `.worktrees/_artifacts/p7-integration-20261111/`.

The owner authorized publication of this qualified result to `origin/develop`,
closure of #165/#161/#156 after verifying publication, and cleanup of their
completed candidate branches/worktrees. Historical cumulative branches and
unrelated work remain outside this cleanup.

The next planned acceptance package is P8. Current issue dependencies put the
approved shared Immersive/Details Viewer redesign (#164) before Pixiv Works
(#140) and independent Work/Page bookmarks (#141). The #161 pagination correction
is adopted early with this P7 qualification and must not be implemented again.
The older combined Pixiv UI is a reference, not the accepted #164 contract.
No P8 implementation was started during this integration.
