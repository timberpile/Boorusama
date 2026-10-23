# Extended option localization

Refs #71. The new `coverage-en-US.json` and `coverage-de-DE.json` are **pending
native i18n CLI manifests**, not already-applied root locale resources. They add
189 option/field labels, 45 descriptions and 53 value labels per language.
JSON parsing and English/German key parity were checked with Python. The
repository CLI, Slang generator and Flutter label widgets were not run here.

Apply them in the task worktree, using the repository's normal tooling:

```bash
fvm dart run i18n_cli:booru_i18n apply docs/handoffs/71-search-options/coverage-en-US.json --dry-run --diff
fvm dart run i18n_cli:booru_i18n apply docs/handoffs/71-search-options/coverage-en-US.json
fvm dart run i18n_cli:booru_i18n apply docs/handoffs/71-search-options/coverage-de-DE.json --dry-run --diff
fvm dart run i18n_cli:booru_i18n apply docs/handoffs/71-search-options/coverage-de-DE.json
./gen.sh i18n
```

If `search_options.ext` already exists in a newer local checkout, reconcile its
children rather than overwriting the object or rerunning a failing add. Commit
the real locale changes. Do NOT reapply the original `i18n-en-US.json` and
`i18n-de-DE.json`; those older manifests were already applied by the local agent.
No permanent startup migration or custom translation loader is introduced.

`labels.dart` normalizes field punctuation only for translation lookups, never
for wire queries. Native `image-width` becomes the localization key
`image_width`. Missing extension descriptions fall back to a native syntax
hint; this is a temporary preparation state, not finished localization. Sorting
choices combine the localized field name and direction. Numeric/unit/native
literal examples remain literal. Dynamic/server-specific vocabulary still
requires native display labels when no curated translation exists.

The UI is not fully localized until these manifests are applied and generated.
A local coverage review should add any missing site-specific labels exposed by
live data rather than inventing descriptions for arbitrary tag suggestions.
