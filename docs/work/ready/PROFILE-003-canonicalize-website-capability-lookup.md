# Preserve website capabilities across equivalent profile URLs

Priority: Normal
Affected feature: Website capability lookup and credential-free profile import

## Problem

Realbooru's registered preset URL ends in `/`, but generated `GelbooruV2Config.siteCapabilities` matches it by exact string. `https://realbooru.com` falls back to generic Gelbooru behavior, losing Realbooru's HTML search, post and tag parsers. A regular Realbooru profile exported without credentials has its URL normalized without that slash by `ProfileExportSanitizer`; importing it as a new profile preserves the slashless URL. This can break search and bookmark metadata recovery even after dependency auto-creation is removed under DATA-010/DATA-012.

## Expected behavior and acceptance criteria

- Equivalent spellings of a registered website URL retain that website's capabilities, including a trailing slash difference, while distinct hosts and installation paths remain separate.
- A credential-free Realbooru profile export imported as a new profile uses the same search and post-recovery parsers as the regular Realbooru preset.
- Preserve profile UUIDs, credentials, account choices, and canonical bookmark identity. Do not add engine-only website fallback or restore automatic dependency profile creation.
- Cover configured and unconfigured website lookup plus the real credential-free export/import path, and verify Realbooru search and bookmark recovery through the UI.

## Context and scope

Relevant code: `packages/booru_clients/tools/templates/site_capabilities.mustache`, generated `packages/booru_clients/lib/src/generated/booru_config.dart`, `ProfileExportSanitizer`, `ProfileImportProjector`, and `gelbooruV2ClientProvider`. Update generator inputs/templates rather than editing generated output directly. Coordinate with [DATA-010](../in-progress/DATA-010-require-site-profiles-for-bookmark-import.md) and [DATA-012](../in-progress/DATA-012-default-and-edit-import-profile-mappings.md). Use public synthetic data and preserve emulator app data. This is a separate follow-up; no implementation is authorized by the DATA-010 review revision.
