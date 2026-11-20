# Local Media Metadata Lookup — #184

Status: **Design draft for owner review; not implemented.**
Issue: https://github.com/timberpile/Boorusama/issues/184
Depends on: #180.

## Intent

When a newly imported local file lacks useful metadata, offer automatic **exact-file** enrichment from already configured booru profiles, without replacing the local file or inventing remote authorship.

## Verified existing mechanisms

`lib/core/posts/cross_profile_lookup/README.md` and `providers.dart` document MD5-based `Find on Other Profiles` for supported Danbooru/Gelbooru/Rule34/Safebooru targets, with validation of returned hash, origin and visibility. Reuse the lookup/capability/visibility and request/cancellation boundaries; do not duplicate engine-specific URL guessing or assume every engine supports MD5 search.

## V1 behavior

- #180 computes the local file's MD5 alongside canonical SHA-256. **SHA-256 remains library identity**, MD5 is merely an optional lookup key.
- On first import of a file lacking source tags/metadata, and only after the user has explicitly enabled online enrichment, schedule an exact MD5 lookup against appropriate configured profiles. Default proposed: disabled until consent. No upload of image bytes solely for hash lookup.
- Keep import successful and local even if a lookup is unsupported, offline, rate-limited, cancelled, hidden by account filters, or returns no match. Avoid repeated searches for unchanged files; record a lightweight last-lookup outcome if needed.
- Verify every returned match by exact MD5 and compatible source/profile; source-URL or artwork-ID matches must not be described as byte-identical. Prefer supported genuine upstream post links in a simple **also found on** presentation.
- Supplement missing tags/categories, rating and source metadata only when unambiguous and compatible; never silently overwrite local edits or choose one conflicting result arbitrarily. Provide a way to inspect matching posts. Keep the local media file in place even after a match.
- Respect account visibility, blacklists and existing privacy settings. Never leak a private file hash to a remote service without explicit user consent.

## Data model / scope

Any retained match reference is for **exact same file**, not a `derivedFrom` relationship. Avoid adding a generic parent/post graph; use a small optional set of verified source references only if UI navigation actually needs persistence. Do not require a remote profile to open a local item later.

A normal `Find on Other Profiles` action remains useful even if automatic enrichment is disabled. General reverse-image search, approximate/perceptual hashes and AI tagging are out of scope.

## Verification

- Single exact match, multiple conflicting matches, no match, unsupported profile, offline import, invalid MD5 response, blacklist-restricted item, consent off/on, cancellation/profile removal and repeated imports.
- No change to the file's SHA-256, local metadata precedence, no silent network calls when disabled, and no new blocking network dependency during import.

## Reviewable product default

Automatic requests start only after one explicit, persisted **opt-in**, not on every installation. Whether the UI additionally offers a one-time "Look up tags" action can be decided during feature review.
