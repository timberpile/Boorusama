# Android Maestro pilot

Live app, live Booru services, disposable app data. No mock backend, special app
storage, native test endpoint, or desktop driver.

Start with [the agent skill](../.agents/skills/test-android/SKILL.md) or
[the local guide](../docs/android_ui_testing.md). `prepare --confirm-reset` clears
the dev app and stages a normal export; only a successful setup flow proves the
import completed. `run` never resets the app implicitly.

## Included scenarios and flows

- `fresh`: no export; the normal non-FOSS dev app creates its default live profile.
- `live-safe`: editable export of one anonymous `Maestro Live Safe` profile using
  Safebooru/Donmai. All other app data starts empty. Media remains live.
- `flows/smoke-navigation.yaml`: settings, empty bookmarks, return to Browse.
- `flows/smoke-import-persistence.yaml`: imported profile survives app restart.
- `flows/common/`: reuse launch, settings and the staged-file import sequence.

The seed uses the existing export schema, not a database snapshot. Change JSON
or unpack a credential-free export from the real app; the packer recalculates
part hashes and lengths. Capture real bookmarks through the app, never fabricate
post metadata just to make a test pass.

## Qualification status

Host-tool unit tests are included under `scripts/tests`. The initial YAML flows
are source-reviewed pilot flows, **not yet qualified on a running emulator**.
The first local run must verify Flutter semantics, the English DocumentsUI file
picker and first-launch overlays. Keep any necessary selector fixes in this
branch and record the AVD/API level and Maestro version in the pilot notes.

Passing navigation is not evidence that live post images loaded. Use Maestro MCP
for a real browse/open/bookmark/restart check during the pilot, with screenshots
and the actual post ID. Do not turn changing live results into fixed-count tests.
