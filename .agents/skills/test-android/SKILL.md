---
name: test-android
description: Use when verifying Boorusama on an Android emulator with Maestro, restoring a disposable live-data scenario, or reusing known UI test actions.
---

# Test Android

Read `docs/android_emulator.md` first. Use this skill with the implementation or
debugging task; it is not a replacement for targeted unit/widget tests.

## Guardrails

- Android only. Real app, live data, no mock backend or separate app storage.
- Claim one exact emulator and keep the lease token in
  `BOORUSAMA_EMULATOR_TOKEN`. Never switch to an unclaimed device.
- Reset only an explicitly disposable environment. `prepare --confirm-reset`
  deletes all dev-app data, caches and logins. Never use it to preserve a user's
  session. The wrapper refuses production packages, physical devices and
  non-debuggable installs.
- Build/install the current branch using FVM before treating results as evidence.
  The runner checks the package, not source/APK equivalence.
- Use the English phone layout. Record unsupported conditions as BLOCKED, not PASS.

## Fast path

1. Check `python3 scripts/android_ui_test.py doctor`. Build/install and claim a
   device as described in `docs/android_ui_testing.md`; no UI automation before
   a valid lease.
2. Run `python3 scripts/android_ui_test.py prepare --device emulator-NNNN
   --scenario live-safe --confirm-reset --run`. Use `fresh` for first-start tests
   or an unpacked export directory for a captured scenario.
3. Run only relevant saved flows, e.g. `python3 scripts/android_ui_test.py run
   --device emulator-NNNN --flow .maestro/flows/smoke-navigation.yaml` or
   `.maestro/flows/smoke-import-persistence.yaml` (requires live-safe).
4. For interactive Maestro MCP, omit `--run` from preparation and execute the
   printed setup file through `run_flow_files`. Renew the lease **before every
   MCP call**, pass the exact `device_id`, and bound operations below 20 minutes.
5. Check actual feature outcomes. For media/bookmarks, open a real post, inspect
   the rendered image, perform the action through the UI, verify the library and
   restart without reset. Record the source/post ID, not an assumed feed index.
6. Inspect relevant screenshots and failures. Report the build, scenario, exact
   checks, evidence paths and PASS/FAIL/BLOCKED. Release the lease in cleanup.

## Reuse rather than rediscover

`common/launch.yaml` starts/restarts without clearing; `common/open-settings.yaml`
requires main navigation with the menu closed; `common/import-staged-export.yaml`
requires a file staged by prepare. Navigation smoke assumes an empty library.
The importer uses the real file picker and preflight; never bypass warnings to
force setup to pass. Initial flows are **not yet emulator-qualified**: verify
selectors on the first local pilot and fix the common flow on failure.

A reset belongs before each scenario, not between its persistence steps.
The wrapper renews before its own commands but cannot guard direct MCP calls.
Use stored YAML via the wrapper for repetition and MCP for interactive work;
do not write ADB coordinate tap scripts or reimplement a UI driver.

## Capture and evaluate

Create state in the real app, export **Custom export without credentials**, pull
the file after lease renewal, and use `scripts/ui_test_export.py unpack/pack`.
Edit JSON or re-export through the app; the packer handles hashes and sizes.
See the guide for paths, sensitive-data review and the public-download reset
boundary. Do not fabricate post metadata or commit credentials.

Record elapsed time/tool calls/manual interventions for the same task with and
without these helpers. Live-data outages, selector failures and product defects
are separate observations. A green navigation flow is not proof of live-media
loading, and staging an export is not proof of a successful import.
