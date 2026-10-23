# Pixiv integration

Pixiv support is **experimental** and intentionally limited. It is not a promise
of feature parity with Pixiv's website or the mature Booru integrations. The
profile authentication tab shows a small localized status label and explanation
both when creating a profile and when editing an existing one.

The notice is informational, not a feature gate. Existing profiles, credentials,
backups, post snapshots, and supported actions keep their existing behavior.
Do not rename saved profiles, require acknowledgement, or disable an existing
capability merely to communicate experimental status.

## Boundaries

Keep Pixiv-specific behavior within this integration and its client package.
Use established shared contracts for real common needs, but do not redesign
shared engine architecture solely to accommodate this limited integration.
Experimental status does not relax authentication isolation, URL validation,
credential redaction, persistence compatibility, or data-integrity requirements.

The current authentication surface supports an OAuth webview on Android/iOS
and manual refresh-token entry elsewhere. Its existing credential warning is
separate from the experimental notice and must remain visible. Never add real
refresh tokens to tests, logs, documentation, or screenshots.

## Verification

`test/boorus/pixiv_experimental_notice_test.dart` covers the informational label,
its explanation, accessibility, and constrained layout in light/dark themes.
After changing localization resources, regenerate the ignored localization
output through `./gen.sh i18n` before running Flutter tests. Exercise both new
and existing Pixiv profiles when changing the configuration surface.
