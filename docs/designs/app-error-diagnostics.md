# Actionable diagnostics for handled warnings and errors

## Goal

Short user-facing warnings and errors should have technically useful diagnostic context without exposing private data. For example, a message such as “Some saved site-specific data could not be read” should identify the decoder or validation stage that failed and why, rather than merely duplicating the UI string.

The suspected logging gaps are an investigation target, **not** a verified claim that all errors currently lack diagnostics.

## Scope

Audit representative warning and error paths throughout the application:

- Startup, persistence, and recovery;
- API/network calls and profile/account resolution;
- Post decoding, search, Following Topics, and feed state;
- Bookmarks and favorite actions;
- Media loading, downloads, and sharing;
- Import/export and backup processing.

Record which areas were actually inspected and any remaining gaps, without claiming exhaustive application coverage from a few examples.

## Requirements

- Add actionable warning/error events at the responsible layer in the existing logging pipeline, including failures represented as fallback/results rather than thrown exceptions.
- Include operation/component and underlying technical reason. Preserve original exceptions and stack traces when available; wrappers must not hide the cause. Include relevant field names and schema/codec versions when safe.
- Differentiate original failure, recovery success, and final recovery failure. Successful silent recovery should not acquire an unnecessary UI error.
- Avoid duplicate entries from rebuilds or repeated propagation of a single failure. Expected cancellation and normal unavailability are not automatically errors.
- **Never log credentials, tokens, authentication headers, complete private payloads, or sensitive search/bookmark values.** Redact URLs and technical references according to existing privacy rules, including exception and stack context.
- Exercise representative failure paths and demonstrate that the root cause is retained. Identify remaining gaps in the implementation report.

This is a diagnostic-quality improvement, not a wholesale logging framework, blanket network-payload logging, or universal debug switch. Reuse existing facilities wherever practical.

See [post architecture](../post_architecture.md), [export/import privacy design](../superpowers/specs/2026-10-01-unified-export-import-design.md), and [existing bookmark recovery](../work/done/POST-008-silently-recover-incomplete-bookmarks-on-open.md).
