# Credential-bearing clipboard export

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`. This is a requested extension of an intentional safety restriction, not a broken serializer.

## Finding

[ExportClipboardService.canCopy](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/backups/export_import/clipboard/export_clipboard_service.dart) immediately rejects `containsCredentials`. Otherwise it permits an encoded payload up to 1 MiB, including `BOORUSAMA-EXPORT:1\n`. `copy()` rechecks the same condition. [_ExportReady](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/backups/export_import/export/export_flow_page.dart) disables Copy BASE64 from this result and passes `state.includeCredentials` to the service. Merely enabling the button would still fail in the service.

The [export flow](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/backups/export_import/export/export_flow_notifier.dart) already carries the credential decision into package creation. Preserve full/custom export semantics and selected profiles. Do not silently strip credentials from an already prepared package or create a second backup format.

## Proposed behavior

Allow Copy BASE64 for a credential-bearing package that satisfies the existing size limit, but require a deliberate per-copy confirmation. The confirmation states that credentials are included, BASE64 is not encryption, and clipboard/history/synchronization can expose the payload. Use a compact localized Kurumi dialog with Cancel and Copy with Credentials. Do not expose the actual credential values in the dialog, toast, logs or analytics. Reuse the existing private-export confirmation intent, replacing/parameterizing its current Material presentation only within this flow.

Separate technical availability (size/platform) from sensitive-copy authorization. Keep the service's default fail-closed for sensitive packages and require an explicit authorization parameter from the confirmed action; disabling a UI check must not bypass the boundary. Bind the decision to the prepared artifact and its credential flag, not a mutable future selection. Prevent duplicate clicks and report write failures without a success toast. Cancellation must leave the clipboard unchanged.

Preserve the prefix and existing package bytes so old clipboard import remains compatible. Keep the 1 MiB encoded limit for this task; suggest normal file export when too large. Do not add encryption, password prompts or automatic sharing services to this scoped change.

## Platform/privacy boundary

[AppClipboard.copyExport](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/foundation/clipboard.dart) currently passes MIME/UTI/text to a native method channel, with a plain-text fallback; its Dart contract has no sensitivity argument. Inspect the native handlers and propagate sensitivity where supported. Android's official [clipboard guidance](https://developer.android.com/develop/ui/views/touch-and-input/copy-paste) requires marking sensitive clips with `ClipDescription.EXTRA_IS_SENSITIVE` to suppress sensitive preview text. This is not encryption and does not make all clipboard histories safe. Do not silently overwrite a later unrelated clipboard value with a delayed cleanup timer.

## Verification

Service/UI tests for non-sensitive normal copy, sensitive confirmation/cancel, size boundaries, duplicate clicks, changed artifact and failed native writes. Round-trip a fake credential-bearing fixture through the ordinary import preflight without logging its contents. Test Android's native sensitive-preview behavior separately from Dart mocks and verify fallback platforms report their real limitations. Use fabricated credentials in committed fixtures. No runtime change or clipboard operation was executed here.
