# Anonymous profile setup fixture

Use this fixture only in a disposable, empty test installation. It is a normal
Boorusama version-1 export package encoded by the existing clipboard envelope,
not a separate configuration format or a test-only import path.

## Contents

The versioned clipboard text is
[`anonymous-profiles-v1.clipboard.txt`](../../test/fixtures/agent_profiles/anonymous-profiles-v1.clipboard.txt).
Its profile payload is also available as readable
[`anonymous-profiles-v1.json`](../../test/fixtures/agent_profiles/anonymous-profiles-v1.json).
The package contains profiles only: no settings, bookmarks, searches, account
credentials, cookies, custom network headers, or personal data.

| Profile | Site | Engine ID | Stable profile ID suffix |
| --- | --- | --- | --- |
| Safebooru (Danbooru) | `https://safebooru.donmai.us/` | 20 | `000000000001` |
| Safebooru | `https://safebooru.org/` | 23 | `000000000002` |
| Konachan (Safe) | `https://konachan.net/` | 24 | `000000000003` |
| e926 | `https://e926.net/` | 25 | `000000000004` |

Every ID has the prefix `a0000000-0000-4000-8000-`. Optional profile settings use
the application's normal defaults. The sites and engine IDs come from
`packages/booru_clients/boorus.yaml`; their availability is not guaranteed by
an offline fixture test.

## Clean-install procedure

1. Follow the [exclusive emulator lease procedure](../android_emulator.md).
   Use a disposable installation with **zero profiles**. Reset an emulator only
   when that scenario is authorized; never clear a signed-in shared test
   installation or personal profiles merely to use this fixture.
2. Copy the entire clipboard file, including `BOORUSAMA-EXPORT:1` and its Base64
   line, to the emulator clipboard using the available clipboard integration.
   Do not paste a file URL, a Markdown code fence, or just the JSON payload.
3. Open **Import** on the empty-profile screen, or **Settings → Backup & Restore
   → Export & Import**, then choose **Import from Clipboard**.
4. Inspect the review: the only source is Profiles, with four creations and no
   removals. The package recommends **Replace** so a clean setup preserves the
   fixed profile IDs. **Cancel if any existing profile would be removed.** Do
   not change the production import defaults to accommodate this fixture.
5. Apply the reviewed import. After the existing restart flow, check Profiles,
   select each profile, and verify Browse/search with a harmless query supported
   by that service. Record live-service failures separately from import failures.
6. Restart the app and verify names, sites, engine IDs, and settings remain.
   Repeat the same procedure on another empty installation and compare the IDs
   by exporting its profiles. Choosing **Copy** instead of Replace intentionally
   generates new IDs and is not the reproducible-baseline procedure.

Fresh-install package import requires the fix for issue #93. The direct setup
entry is provided by #94; the Settings route remains usable without it. This
fixture does not bypass import review, warnings, or dependency validation.

## Verification and maintenance

Run the focused reader/clipboard/source-validation/projection test:

```bash
fvm flutter test --no-pub --concurrency="$(python3 scripts/physical_core_count.py)" \
  test/core/backups/agent_profile_fixture_test.dart
```

The test compares the archived source bytes with the readable JSON, verifies the
real package reader, checks the strict credential-field allowlist, and ensures
Replace projects the same IDs and settings on repeated empty installations.
It does not make live service requests or replace Android clipboard acceptance.

Keep the fixture version, export ID, profile IDs and payload stable. For an
intentional revision, add a new versioned fixture and regenerate the package
using `ExportPackageWriter`, then encode it with `ExportClipboardService.copy`.
Update the test and this procedure together. Do not add credentials to make
anonymous checks pass.
