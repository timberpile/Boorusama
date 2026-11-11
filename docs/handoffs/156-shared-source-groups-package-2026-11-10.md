# P7: existing source Groups on shared contracts

Issue: #156. Base: published P6 `2e2ea428ba323706e37a65e45903d3959df439d4`.
The owner authorized P6 publication and subsequent P7 implementation. P6 is
published, #143 is closed, and its completed package branch/worktree is removed.
P7 remains local for owner acceptance; publication and integration are pending.

## Delivered behavior

Danbooru Pools/direct Related families and Szurubooru Pools now use registered
`ContentGroupSource` adapters and `ContentGroupPage` inside the existing mixed
viewer. Native routes are thin entry points. Legacy Pool-specific viewer dispatch
and synthetic cover Posts no longer participate in runtime rendering.

Adapters preserve identity independently of Pool category, unknown and empty
manifests, source positions, missing members, duplicates and out-of-order batches.
Numeric pages use bounded indexed requests. Related uses raw listing progress
through visibility-filtered batches. Per-occurrence ordering, selection,
checkpoints and normal member-viewer Back behavior remain; content actions collapse
duplicate members without collapsing their displayed occurrences. Group entries
have no active Post, zoom, playback or Post actions. Preloading resolves only
real Posts in the existing bounded window.

Generic Bookmark Groups saving and static cover descriptors use the captured
access context. Refresh preserves saved IDs, memberships and membership dates.
Portable Group links and `.bslink` files carry validated engine/site/Group identity,
without credentials or profile hints. Public readers remain limited to approved
source installations; this package adds no anonymous-source grants. Accepted P4/P5
storage, hierarchy, picker, import and unavailable-count behavior, and P6 policy,
media/cache and icon behavior are preserved.

Review and device findings resolved before qualification:

- Public native routes and Search retain their read actor instead of fabricating
  a saved-profile binding; existing private-account revocation guards remain.
- Pool refresh invalidation is reference-scoped. Unrelated pending reads survive.
  Initial loading does not invalidate sibling metadata while widgets build.
- Other occurrences of the same Group revoke old pagers immediately. Late results
  cannot mix manifests. Numeric pages retain the selected page; infinite lists
  restart coherently. Inactive occurrences defer requests. Refresh suppression
  includes the exact access/reference key, including policy transitions.
- A native Szurubooru member could trap system Back when its reader differed from
  remembered Browse. The navigation shell now returns to an existing root caller
  while allowing child selection/sheet vetoes to consume Back. It does not change
  the selected profile or navigation preferences. No additional route, marker,
  viewer or vendored-router change was needed.

## Final automated verification

Checked runtime/test commit: `fbefa7c248e93f02ca0d83a7c956bd4e6e888946`.
Checked tree: `d5dc5b479f919d548fd4c813a380372c04e95f66`.
Both qualification processes started on clean, frozen inputs. Subsequent changes
are documentation only; the runtime/test/dependency tree remains equivalent.

- Missing generated output required `./gen.sh`; generation and localization
  validation succeeded. Changed Dart files were formatted with FVM.
- `fvm flutter analyze --no-pub` over 89 affected Dart files: 0 errors, 0 warnings,
  101 informational findings (exit 1 due to those findings).
- `./scripts/run_regression_tests.sh`, physical-core concurrency 6, exit 0:
  6,899 application tests; 1,686 package/CLI tests across all 13 roots; both shell
  suites; 76 Python tests. Two existing GoRouter skips remain. The documented
  libavif directory-input warning did not interrupt the completed gate.
- Focused production-router checks include different/recovery Browse actors,
  unchanged global selection/preferences, nested Related/member Back, selection,
  expanded sheets, Group header Search, and retained bookmark destinations.
  The final navigation run passed 112 tests. Controlled peer-refresh regressions
  cover active/inactive and numeric/infinite variants and late completion.
- Independent GPT-6.1 Sol High approved source at this exact commit. Final
  evidence reconciliation is retained with the durable logs. Superseded and
  interrupted runs are not the final qualification.

## Native and live-service qualification

Maestro controlled exclusively leased `emulator-5554`, at 320dp and 2x text.
The connected physical device was untouched. Internal APKs use normal
`lib/main.dart`; no review APK was delivered.

The initial source-approved candidate `aaab9a3996f377ecd95e76aa824ebc9dafb45903`
used APK SHA-256
`7e1bcac47a219856d5f78fab045cf011385a9b62031d3e7a2f1d8a6fbe0184c9`.
With zero saved profiles, real public AIBooru (Danbooru engine) Pool 151 loaded
11 members, opened an Original member image and returned to its gallery. The
existing Kurumi picker saved it into Default; the title/count remained after a
cold restart. An unknown cover correctly remained without an invented cover Post.
Related family 184580 opened its member and returned. Pool 80 loaded all 130
members across three 60-item batches. Deep member Back restored a byte-identical
viewport screenshot (SHA-256
`5d0d1233a1c4e9105b0162330083eabce00ee34f1561b45480412c3fde332fcc`).
Rotation retained 130 loaded members; revealing the collapsed floating toolbar
confirmed the count. No native crash or overflow was found in those actions.

The owner supplied `https://jej.lol/pool/5`. Its Pool and known-member APIs returned
HTTP 200 without credentials. A temporary configured Szurubooru reader was created
through normal UI with login/API key blank. The real `chipwife` gallery displayed
all 29 members, description and order controls. Its member Back failure prompted
the final navigation fix above.

Final normal APK SHA-256
`adee2383338f1233f4c1561726608b07de7e5579c01dd831cdca76e500f2e8c7`
matches both build and installed provenance for exact `fbefa7c24`. The same live
Szurubooru Pool displayed its 29 members. A decoded full-screen member ImageView
returned to the same gallery/member bounds with one system Back. Long-press
selection showed one selected item; Back cleared selection and retained the
gallery. Header Search displayed `pool:5` and 29 Posts. At 2x text, opening and
dismissing the keyboard followed by route Back returned to `chipwife`.

Limits: launch followed immediately by a deep link initially remained on Browse;
opening the link after startup settled succeeded. This is not cold-start link
acceptance. Szurubooru does not expose an `Original` accessibility label; that
attempted assertion failed, and the retained decoded ImageView hierarchy is the
actual media evidence. Profile-removal/revocation, repeated outer occurrences
and refresh races were qualified by host tests rather than additional live
device scenarios. AIBooru verifies the Danbooru adapter, not every Danbooru
installation or authenticated service. These checks do not establish performance
budgets or unrestricted site support.

## Restoration and retained evidence

The original APK and all nine data roots were restored. Exact normalized archive
comparison passed for 1,108 entries with zero missing, extra or changed members,
including types, modes, sizes and hashes. APK, 31 permission lines, font/window/
rotation/animation settings and stopped state match baseline. No network settings
were changed. Only journal-owned QA parking was removed; the original application
remains stopped and the exclusive lease was released. An initial sandbox denial
occurred before any restoration mutation; the preserved empty journal records it.
Restoration then completed through approved ADB access.

Evidence: `.worktrees/_artifacts/p7-package-20261110/` (ignored), especially
`final-checked-candidate.json`, `final-verification-result.json`,
`regression-fbefa7c24.log/.exit`, `analysis-fbefa7c24.log`,
`final-root-caller-source-review.md`, and `native/final-native-result.json`.
The isolated local branch is `maintenance/156-shared-source-groups-package` in
`.worktrees/156-shared-source-groups-package`. Historical and unrelated worktrees
and the primary detached checkout remain untouched.
