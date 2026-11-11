# BASE64 import entry with manual input

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`.

## Current behavior

[ExportImportPage](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/backups/export_import/export_import_page.dart) shows Import from Clipboard, checks `clipboard.detect()`, and immediately reads/stages the clipboard on tap. [ExportClipboardService](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/backups/export_import/clipboard/export_clipboard_service.dart) requires `BOORUSAMA-EXPORT:1\n`, decodes BASE64, writes a temporary `.bsexport`, and returns a disposer. The caller opens the ordinary ImportFlowPage with that path and disposer.

## Proposed UI

Replace the entry with localized **Import BASE64**. Open a compact responsive Kurumi form with one multiline plain-text input, an explicit **Read Clipboard** action, and Cancel/Continue. Clipboard reading fills the same field; manual paste and typed text follow exactly the same path. Do not read the clipboard automatically on opening or require a positive detection result to use manual input. Detection hints are optional and should not control availability.

Keep the field scrollable and the footer reachable with the keyboard and enlarged text. Disable autocorrect/suggestions, do not persist text in settings/history or state restoration, and never include its value in error messages. Show concise validation errors without destroying the user's input. Avoid repeatedly decoding on every keystroke or rendering a decoded credential preview. Continue validates and opens the existing import preview; it does not immediately apply an import.

## Parsing and integration

Extract a pure text-to-package decoder from `importToTemporaryFile()` and a separate staging function. Accept both the existing versioned prefixed text and raw BASE64 for a Boorusama export package. For a recognized prefix with an unsupported version, report unsupported format rather than treating it as raw data. Permit outer whitespace and deliberate ASCII line wrapping in BASE64, but do not remove arbitrary punctuation or guess JSON/URLs/other archives into a valid export.

Enforce the existing 1 MiB encoded input ceiling before normalization/decoding, then validate decoded package size/type through the existing package reader. Retain archive decompression limits, schema validation, dependency planning, profile mapping, preview, mutation coordination and transactional rollback. BASE64 validity alone is not proof of a valid Boorusama export. Keep `.bslink` navigation separate from backup import.

Pass staged bytes into ImportFlowPage using the established source-durability and disposeInput ownership. Ensure failed staging deletes its partial temporary file; cancellation and route disposal clean up exactly once, while an executing transaction/recovery process retains any required durable source. Do not invent a second importer or loosen #142's profile-independent preservation rules. Export output stays prefixed for backward compatibility.

## Verification

Pure tests for legacy prefix, raw BASE64, CRLF/wrapped text, empty input, invalid characters, unsupported prefix version, boundary/oversize input, valid BASE64 containing an invalid archive, malformed/unsupported schema and archive expansion limits. Widget tests for manual entry with no clipboard permission, clipboard fill/error, duplicate Continue, cancellation, keyboard and enlarged text. Reuse zero-profile import and credential-bearing fake fixtures; ensure preflight failures never mutate the library. Native clipboard permission behavior still needs Android acceptance.

No code, localization or runtime tests were changed or executed by this investigation.
