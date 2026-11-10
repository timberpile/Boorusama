# P6: public and offline saved Post access

Issue: #143. Base: published P5 `fc98385dde39a8474e7f053526bc8e367362ee7e`.
The owner accepted final E-shuushuu behavior and authorized publication, followed
by P7 (#156). This package preserves accepted P4/P5 storage and UI behavior.

## Delivered behavior

Fresh saved Posts prefer exact or uniquely compatible profiles despite obsolete
imported hints. Captured viewers/actions retain their actor and revoke when it
changes. Existing Pool/Related binding remains strict until P7. Explicit known
sites receive reusable, credential-free, read-only anonymous scopes with bounded
HTTPS methods, destinations, redirects and media paths. Catalog authentication
metadata can veto grants; it does not enable every optional-login site.

Bound media checks actor and established Post visibility before cache, decoding,
preload or transport. Rating/deleted/banned/blacklist rules remain authoritative;
ordinary Browse controls and revealable blur behavior remain. Images keep normal
URL/custom keys; videos keep stable `content-media` storage. Cached Danbooru
policy does not await a current-user network response. P5 unavailable totals and
site counts remain scoped to the current timeline/tags/source. The total is beside
the title; temporary failures have retry. The removed persistence notice stays removed.

Owner feedback fixes:

- Realbooru retained `//images/...` URLs now pass the narrow known-directory rule,
  without URL/cache rewriting. JPEG/MP4 and Original-versus-thumbnail tests cover it.
- Anonymous icons use only the exact registered-source favicon through the existing
  credential-free client. Imported custom icons remain blocked; revocation is tested.
- Added specifically requested E-shuushuu and HypnoHub public readers. This is not
  automatic support for every site without required authentication.
- Actual E-shuushuu media redirects to `cdn.e-shuushuu.net/fullsize/...`. Guarded
  live transport proved that rejection caused the Android failure. Only that media
  CDN was added; CDN API routes and unrelated hosts remain denied. No speculative
  TLS/protocol or metadata-hydration changes were introduced.

## Final verification

Checked runtime/test commit: `44de226fce28c03c5b3d7b2b55a245d7435ee6f5`.
Checked tree: `778146dfc6830c992b0654b236bd4b77749269d4`. Qualification ran clean;
subsequent handoff edits are documentation only. Refreshed `origin/develop` still
matched the P5 base above.

- Missing generated output: `./gen.sh` succeeded, including localization validation.
  Changed Dart files were formatted with FVM.
- `fvm flutter analyze --no-pub` over 110 changed Dart files: 0 errors, 0 warnings,
  127 informational findings (exit 1 due to those findings).
- `./scripts/run_regression_tests.sh`, physical-core concurrency 6, exit 0:
  6,784 application tests; 1,686 package/CLI tests across all 13 roots; both shell
  suites; 76 Python tests. Two existing GoRouter skips remain. The known libavif
  directory-input warning is documented in `docs/build_troubleshooting.md`;
  it did not interrupt the completed gate. Superseded runs are not qualification.
- Feedback checks cover Original pixels, icons, reattachment/revocation, exact
  transport destinations and credentials. Three indicator tests include title/count
  placement, narrow width, enlarged text and keyboard. CDN transport/policy: 28 passed.
- Independent GPT-6.1 Sol High approved source at exact `44de226fc`; final gate/native
  evidence reconciliation is retained beside the durable logs.

## Current-source Android and live evidence

Normal `lib/main.dart` APK for `44de226fc` was built and installed with matching
SHA-256 `e61d5ad3f2264bfce55753d1993f0eb1dd1b604623da97867f378e83f252a927`.
No review APK was delivered. Maestro controlled exclusively leased `emulator-5554`;
the connected physical device was untouched. Five synthetic saved Posts with zero
profiles exercised media at 320dp/2x text.

Realbooru MP4 reached 0:13/0:13 and cached all 8,428,380 bytes. Realbooru Original,
HypnoHub and E-shuushuu full image viewers loaded. The corrected grid had no retry
or unavailable entries. Guarded E-shuushuu transport returned HTTP 200 and 321,586
image bytes. Realbooru image/video and both new public APIs returned HTTP 200.

With airplane mode, Wi-Fi/data disabled and no active default network, the app was
force-stopped and cold-launched. Realbooru video again reached 0:13/0:13; Realbooru
and E-shuushuu Original viewers decoded images without retry. Warm image cache
files were 444,158 and 321,586 bytes. Playback evidence is
`cold-offline-realbooru-video-actual.json`; the earlier filename without `-actual`
records a grid mistap and is not a pass.

No current-package create/remove-profile UI scenario was completed; focused provider
tests cover reattachment and captured-actor revocation. Synthetic media seeding is
not new import-dialog acceptance. These results do not establish all-site support
or arbitrary authenticated/live-service availability.

Original APK and all nine data roots were restored. Exact comparison passed for
1,108 entries with no missing, extra or changed members, including type/mode/hash
checks. APK, 31 permission lines, stopped state, window/font/animation and network
settings match baseline. Only journal-owned QA directories and hash-verified staged
fixtures were removed. The original app remains stopped; the lease was released.

Evidence: `.worktrees/_artifacts/p6-package-20261110/` (ignored), especially
`final-checked-candidate.json`, `final-verification-result.json`,
`regression-44de226fc.log/.exit`, `analysis-44de226fc.log`, and `native/`.

## Automatic approval limitations

The connected progress-comment tool exposed a PR-number schema; automatic review
rejected that call. No comment or indirect workaround was attempted. Automatic
review also rejected an earlier broader source-policy proposal before execution.
Delivery was narrowed to the two expressly requested sites; other catalog entries
receive no additional transport permission.
