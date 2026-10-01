# Migrate data from AnimeBoxes

The Boorusama CLI can convert an AnimeBoxes **Android 1.0** CSV export into a
readable intermediate JSON file and then into Boorusama backup files. The
conversion is local and does not contact any servers.

## Protect the source export

An AnimeBoxes export can contain profile usernames and passwords in plaintext.
Keep the CSV outside source control, restrict access to it, and delete it when
the migration is complete. Rotate any credentials contained in the export
afterward. The converter records only whether credentials were present; it
does not copy their values into normalized JSON, output files, diagnostics, or
terminal output.

## Convert the export

From `packages/boorusama_cli`, run:

```sh
fvm dart run bin/boorusama.dart animeboxes normalize \
  --input /path/to/animeboxes.csv \
  --output /path/to/animeboxes.normalized.json
```

Review the normalized JSON before continuing. It gives every supported CSV
field a name and includes profiles, search history, bookmarks, blacklist
rules, pinned-search folders, and pinned searches.

Then create the Boorusama backup files in a new directory:

```sh
fvm dart run bin/boorusama.dart animeboxes export \
  --input /path/to/animeboxes.normalized.json \
  --output-dir /path/to/new-output-directory
```

The output directory contains:

- `boorusama_bookmarks.json`
- `boorusama_blacklisted_tags.json`
- `boorusama_pinned_searches.json`
- `conversion_report.json`

The bookmark backup places every converted bookmark in an `AnimeBoxes` group.
The group has no stored identity, so every import creates a fresh group instead
of conflicting with an existing one.

`conversion_report.json` contains aggregate counts and non-sensitive warnings,
including duplicate resolution, unsupported settings, or folder names that
were adjusted for Boorusama compatibility.

## Import into Boorusama

Use Boorusama's backup screen in this order:

1. Configure the corresponding Boorusama profiles manually.
2. Import `boorusama_bookmarks.json`.
3. Import `boorusama_blacklisted_tags.json`.
4. Import `boorusama_pinned_searches.json`, review the profile-matching
   preflight, and skip only profiles that you intentionally want to leave
   unmatched.

Pinned-search profile matching uses the engine and normalized server URL. A
source profile ID is only a matching hint; it does not create a Boorusama
profile.

## Scope and failure behavior

Bookmarks, blacklist rules, and pinned searches are converted into importable
backups. Profile definitions and search history remain available for review in
the normalized JSON but are not converted into Boorusama backups. AnimeBoxes
pinned-search settings without a Boorusama backup equivalent are listed in the
conversion report.

Both commands validate the complete input before replacing their destination.
An existing destination is preserved if validation or writing fails, and the
export command does not leave a partially populated output directory. The
normalized JSON schema is strict, so unknown or malformed fields stop the
conversion instead of being silently ignored.
