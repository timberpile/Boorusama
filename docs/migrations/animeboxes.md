# Migrate data from AnimeBoxes

The Boorusama CLI converts an AnimeBoxes **Android 1.0** CSV export into a
readable intermediate JSON file, then one current `.bsexport` migration package.
Conversion runs locally and does not contact servers.

## Protect the source export

An AnimeBoxes export can contain profile usernames and passwords in plaintext.
Keep the CSV outside source control, restrict access to it, and delete it when
the migration is complete. Rotate any credentials contained in the export
afterward. The converter records only whether credentials were present; it
does not copy their values into normalized JSON, the package, the report,
diagnostics, or terminal output.

## Convert the export

From `packages/boorusama_cli`, run:

```sh
fvm dart run bin/boorusama.dart animeboxes normalize \
  --input /path/to/animeboxes.csv \
  --output /path/to/animeboxes.normalized.json
```

Review the normalized JSON. It names every supported CSV field and includes
profiles, search history, bookmarks, blacklist rules, pinned-search folders,
and pinned searches, without credentials.

Create the migration package in a new directory:

```sh
fvm dart run bin/boorusama.dart animeboxes export \
  --input /path/to/animeboxes.normalized.json \
  --output-dir /path/to/new-output-directory
```

The directory contains exactly:

- `animeboxes.bsexport`, containing bookmarks, blacklist rules, and pinned searches.
- `conversion_report.json`, containing aggregate counts and non-sensitive warnings,
  including duplicate resolution, unsupported settings, and adjusted folder names.

Profiles and search history are excluded from the package. They remain in the
normalized JSON for review. Package parts declare their current source schemas,
byte lengths, SHA-256 digests, selections, and safe import recommendations.
Identical normalized input produces byte-for-byte identical output.

## Import into Boorusama

1. Configure corresponding Boorusama profiles manually.
2. Open **Export & Import**, choose **Import file**, and select `animeboxes.bsexport`.
3. Review the imported items. Bookmarks and pinned searches use **Per item**
   with **New copy** recommendations for the AnimeBoxes group and folders.
   These choices preserve existing bookmarks, groups, and local-only pins.
   Selected reused pins may move to a copied folder, as explained below.
4. Explicitly map each unresolved pinned-search source profile to the intended existing
   account. Matching a site alone does not select an account. Import remains
   blocked until required profile references are resolved, or their pins are skipped.
5. Leave blacklist rules on **Skip** to keep existing rules. The current app
   supports only whole-category **Replace** for blacklist rules: choosing it
   intentionally discards local rules and uses the imported rules. Review that
   choice before applying.
6. Check the change preview and apply the import.

Every converted bookmark belongs to an `AnimeBoxes` group. The package now
stores a deterministic group UUID, as required for current item selection;
**New copy** creates a fresh local group, including when importing the same
package again. Names are display labels. Existing canonical bookmarks and
selected identical pinned-search queries within a mapped profile are reused.
Copied folders receive a unique name such as `Folder (2)` when their name
already exists. When a source profile UUID already matches a local profile,
repeat review recognizes existing queries and skips those searches, preserving
their memberships. A fresh source UUID explicitly mapped to an existing account
can instead reuse selected queries. A pin has one folder or Home destination:
**New copy** moves those selected reused pins to the copied folder, leaving
local-only pins in their existing folders. Choose **Merge** or **Merge into**
to keep the original folder's local-only membership together with selected
imported pins.
Imported folder order and Home search order are retained; local collections
keep their relative order as imported folders are placed among them.

Source profile references use deterministic UUIDs derived from the AnimeBoxes
profile ID, engine, and portable site URL. They are references rather than
profile definitions and never carry login details. Account display names and
export dates do not change those UUIDs. Manually edited normalized profile and
pin site URLs must exclude query, fragment, and user information; they are
rejected before output writes. Host case, default ports, and trailing slashes
are canonicalized before reference UUIDs are generated.

## Scope and failure behavior

Bookmark source version 4 stores canonical site/upstream-post identities and
post snapshots. Different posts sharing a media URL remain separate bookmarks.
The site namespace retains non-default ports, including HTTP on port 443.
The converter retains the supported known-site/root-URL normalization contract;
it does not infer installations from API paths or add unsupported engines.
Same-host profiles with different canonical site namespaces are rejected before
host-based source matching to avoid silently choosing one installation. Multiple
accounts at the same site, including HTTP/HTTPS default-port forms, remain
supported and require explicit profile review.

Pinned queries preserve the main search text followed by AnimeBoxes
`extra_tags`, which already contains its selected extra filters and ordering
terms. These terms are appended once; UI selector fields such as
`danbooru2_is_has`, `danbooru2_order`, and `gelbooru_order` are not appended again.
A blank main query is supported when `extra_tags` supplies search terms. A
non-text `extra_tags` value or a genuinely empty combined query stops export
before writes. Normalized JSON retains the original separate fields for review.

The report includes `duplicate_pinned_query_identity` when multiple definitions
share a source profile and effective query after whitespace normalization.
Every definition and source order remains in the package. The app reuses one
pin per mapped profile/query. Selected Home membership takes precedence for
repeated definitions; otherwise the first selected imported folder keeps that
pin. Local-only membership is preserved
according to the chosen Copy/Merge action described above.

Other AnimeBoxes pinned-search settings without a Boorusama equivalent are
listed in the conversion report. Profile-level rating filters and the
AnimeBoxes `#fullhd` shortcut expansion remain outside this conversion scope;
configure corresponding local profile settings and review such queries manually.
The package contains definitions and organization only, not refresh state or
downloaded posts.

Both commands validate complete input before writing their destination.
An existing destination is preserved if validation or writing fails, and the
export command publishes the package and report directory atomically without
leaving a partial final directory. The normalized JSON schema is strict;
unknown or malformed fields stop conversion instead of being silently ignored.
Older loose JSON outputs are not supported by the current importer. Regenerate
the package from the source CSV or validated normalized JSON.
