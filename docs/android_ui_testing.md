# Android UI testing MVP

Use disposable Android emulators and real Booru data. Setup is deliberately small:
**clear the dev app, import a normal export, run a few saved Maestro flows.**
There is no app-code change, test storage namespace, mock backend, desktop support,
automatic build cache, or dev-only reset button in this MVP.

## Requirements and reset boundary

Linux/macOS host (the existing lease script uses `fcntl`), Python 3.10+, FVM,
Android SDK/ADB, and Maestro CLI or Maestro MCP. Use an unlocked English-language
phone emulator with the normal, non-FOSS **debug dev** APK installed. The package
is fixed to `com.timberpile.boorusama.dev`; `run-as` must work. The production app
and physical devices are not accepted by the runner.

`prepare --confirm-reset` is destructive: Android `pm clear` removes the app's
persisted data, settings, logins and app-owned caches. It stops the app; nothing
is restored except what the chosen export contains. This is an **app reset**, not
an emulator factory reset: public Downloads/media, the OS clipboard, other apps
and device settings are not wiped. The runner removes/replaces only its reserved
`/sdcard/Download/boorusama-ui-test.bsexport` file. Do not store personal files
under that name. Shared-download, system-dialog and permission tests are outside
this initial suite; use a wiped AVD when those need a genuinely clean device.

Use a dedicated disposable AVD, not a colleague's signed-in emulator. This
explicit pilot exception does not authorize wiping other test environments.

## First run

Build the current task branch before reserving an emulator; follow the normal
repository setup if generated files or dependencies are missing:

```sh
python3 scripts/android_ui_test.py doctor
fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json
adb devices -l
python3 scripts/emulator_lease.py claim emulator-5554 --owner "maestro-pilot $(pwd)"
# Copy the returned token, without saving it in a tracked file:
export BOORUSAMA_EMULATOR_TOKEN='<returned-token>'
python3 scripts/emulator_lease.py renew emulator-5554 --token "$BOORUSAMA_EMULATOR_TOKEN"
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-dev-debug.apk

python3 scripts/android_ui_test.py prepare --device emulator-5554 \
  --scenario live-safe --confirm-reset --run
python3 scripts/android_ui_test.py run --device emulator-5554 \
  --flow .maestro/flows/smoke-navigation.yaml
python3 scripts/android_ui_test.py run --device emulator-5554 \
  --flow .maestro/flows/smoke-import-persistence.yaml

python3 scripts/emulator_lease.py release emulator-5554 --token "$BOORUSAMA_EMULATOR_TOKEN"
unset BOORUSAMA_EMULATOR_TOKEN
```

Replace the example serial everywhere with the one actually claimed. The runner
renews before every ADB operation and Maestro CLI call, aborts on lease failure,
and limits each CLI flow to 15 minutes. It does not claim or release ownership on
an agent's behalf: retain the same lease for interactive checks, and release it
in cleanup even after a failure. If interrupted, confirm no UI operation remains
active before releasing. Do not invoke the entire `.maestro` directory as a suite:
common flows have preconditions and must not be run as independent tests.

`doctor` lists host executables only, not a verified SDK/device installation. FVM
is needed for building; Maestro CLI is only needed for `--run` and `run`.
`prepare` without `--run` needs ADB and can be followed by MCP execution.

Record `git rev-parse HEAD`, relevant uncommitted changes, the build/install
commands, Android API/AVD and `maestro --version` with the pilot. The wrapper
checks package identity/debuggability, **not equivalence of an installed APK to
local source**. Never reuse an old APK as evidence for a new change.

## Maestro MCP workflow

Omit `--run` from `prepare`. It prints the generated `setup.yaml` path and leaves
the result explicitly **staged**, not verified. Renew the lease, then execute
that file with Maestro MCP's `run_flow_files`, using the exact `device_id` and
absolute flow path. MCP can also execute the saved smoke/action flows. Before
**every** further MCP call, renew the lease manually; the Python wrapper cannot
intercept direct MCP tools. Keep each operation below the lease's 20-minute
operation limit, and take a fresh screenshot/hierarchy on a selector failure.

The CLI exception is limited to saved Maestro YAML through the wrapper. Continue
using MCP for interactive UI exploration; do not replace it with ADB tap scripts.
MCP output is separate from the wrapper's CLI reports; record it explicitly.

## Scenarios are normal exports

`fresh` resets without importing. Normal app startup creates its real default
profile. `live-safe` additionally replaces profiles with the version-controlled
anonymous Safebooru/Donmai profile in `.maestro/scenarios/live-safe`. It does not
cache responses or freeze live media. Its initial bookmarks and histories are
empty because the app was cleared, not because a new test store was introduced.

To make a bookmark/settings scenario, prepare the disposable app, configure it
normally, and bookmark a small chosen set of real posts. In **Settings → Export
and Import → Create export → Custom export**, choose the needed data categories
and **disable credentials**. Do not choose Full export: that includes credentials.
Keep the app and emulator in English for these first text-selector flows. Save
the resulting `.bsexport` to Downloads, renew the lease and pull that exact file:

```sh
mkdir -p build/android-ui-tests/captures
python3 scripts/emulator_lease.py renew emulator-5554 --token "$BOORUSAMA_EMULATOR_TOKEN"
adb -s emulator-5554 pull /sdcard/Download/my-export.bsexport \
  build/android-ui-tests/captures/bookmarks.bsexport
python3 scripts/ui_test_export.py unpack \
  build/android-ui-tests/captures/bookmarks.bsexport .maestro/local/bookmarks
# Review and edit the unpacked JSON in your editor.
python3 scripts/ui_test_export.py pack .maestro/local/bookmarks \
  build/android-ui-tests/captures/bookmarks-edited.bsexport
python3 scripts/android_ui_test.py prepare --device emulator-5554 \
  --scenario .maestro/local/bookmarks --confirm-reset --run
```

Directory scenarios are automatically packed during preparation; manual `pack`
is useful for sharing an edited export. A `.bsexport` file can also be passed
directly to `--scenario`. The packer preserves the existing source format and
regenerates SHA-256/byte lengths. It does not convert or migrate app data schemas.
It supports opaque database parts, but edit those through the app and re-export.
Versioned JSON exports are preferable to copying raw Hive/app directories.

Review the diff before moving a local scenario into `.maestro/scenarios/<name>`.
Record its purpose, source sites, important post IDs, expected groups and checks
in an adjacent README. Keep images and API responses out of fixtures. The host
checks the credential flag and common secret fields in JSON, **not every possible
secret in binary databases or free text**; this is not a security audit. Do not
commit credentials, raw private exports or live-account screenshots.

For full-reset scenarios, omitted categories start at app defaults. Exported
categories use the importer's normal actions; choose Replace in the export's
suggested actions when desired. The seed already does this for profiles. App
preflight is still authoritative: the automated importer requires **All checks
passed** and does not automatically acknowledge warnings. A custom scenario must
also have its own content assertions after setup; generic import success alone
does not prove every expected setting/bookmark is present.

## What the flows prove

`smoke-navigation` assumes a just-prepared `fresh` or `live-safe` scenario with
empty bookmarks. It checks Settings, the empty library, and return to Browse.
`smoke-import-persistence` requires `live-safe`; it checks that the replacement
profile exists, the default profile is gone, and this survives process restart.
Neither flow claims successful image decoding, a search-result count, bookmark
creation, or network health. Permission grants are explicit for these smoke
flows; they do not exercise Android permission prompts.

Reset **before a scenario**, not between steps of a persistence test. The common
launch flow and `run` never clear state. Useful shared actions are `common/launch`,
`common/open-settings` and `common/import-staged-export`; inspect each precondition
before reusing it. These text selectors assume English and phone navigation.
Flutter widget Keys are not Maestro resource IDs. Inspect the real hierarchy;
add targeted Semantics identifiers later only where the pilot proves necessary.

## Results, failure handling and initial qualification

CLI runs write `result.json` (status, elapsed time, device, flow, exit code), a
JUnit report, Maestro debug output and screenshots under
`build/android-ui-tests/<device>/<run>/`. Preparation writes `prepare.json` and
its generated flow/export there. An existing output directory is never replaced.
A nonzero Maestro exit stays nonzero. Timeouts or failed prerequisites are not
passed tests. On failure, inspect the stored evidence; do not retry until green.
Classify a live service outage/rate limit as an external blocker when supported
by evidence, separately from an app failure or an automation/selector failure.

**Initial status:** host utilities have unit coverage; no emulator/Flutter run
was available during creation. YAML is source-reviewed, not device-qualified.
The first local agent must validate the file picker, startup overlays, navigation
labels and profile import on its actual AVD. Fix those shared flows once, rather
than teaching every agent a different coordinate sequence. This branch is a pilot,
not a mandatory CI gate and not yet a fully verified integration candidate.

For the pilot, have a fresh-context agent perform these tasks first manually via
MCP and then with the skill on comparable fresh resets: reach Settings, restore
`live-safe` and confirm persistence, then open a live post, bookmark it and find
it after restart. Record the real site/post ID and inspect its image; navigation
alone is not enough. Repeat on another session after initial setup costs.
Use a small note per run:

```text
commit / local changes / APK build/install evidence:
AVD + Android API + Maestro version:
task + scenario + manual-MCP or skill-assisted:
total wall time / prepare seconds / UI seconds:
agent tool calls / manual interventions:
PASS, FAIL or BLOCKED + exact assertions + evidence paths:
selector fixes / service failures / one next improvement:
```

A successful pilot reduces repeated navigation/setup work without weakening the
assertions. Measure that before expanding into build services, many scenarios,
automatic CI or an in-app reset button.

Host checks (no emulator needed):

```sh
python3 -m unittest discover -s scripts/tests -p 'test_*ui_test*.py' -v
```

The normal repository regression runner already discovers these tests. Run the
complete local regression suite and the actual emulator pilot before integration.

References: [Maestro CLI](https://docs.maestro.dev/maestro-cli/maestro-cli-commands-and-options),
[launch/permissions](https://docs.maestro.dev/reference/commands-available/launchapp),
[Android package manager](https://developer.android.com/tools/adb#pm).
