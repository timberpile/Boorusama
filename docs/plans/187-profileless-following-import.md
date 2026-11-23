# Profileless Following Topic imports

Issue: [#187](https://github.com/timberpile/Boorusama/issues/187)

Source baseline: `b81cffd3253a8ac873b293493fb4c3ad9d4619d6`.
Task branch: `feature/187-profileless-following-import`.

## Outcome and boundaries

Valid Topic definitions must survive import without a configured account. Storage is independent of current network access; unsupported/private sources remain retained. Reuse the existing anonymous transport, source policy, refresh limits and Topic UI. Do not create saved profiles, expand the public-site allowlist, change MiteMite ownership, or change deliberately account-bound local-copy behavior.

Current folder feeds are organization over ordinary Topics and belong in this change. Legacy standalone `following_feeds` remains profile-bound unless its separate source importer is deliberately extended and tested. Ordinary profile-owned Topics retain existing deletion semantics; newly detached imports must not acquire that ownership merely because a matching profile becomes available.

## Architecture decision

Reuse `FollowingTopic.localSource`, which already survives Hive and runtime-snapshot serialization. Add explicit portable import provenance to `FollowingTopicSource`, rather than treating a foreign profile UUID as local account authority. Old local-copy source JSON keeps its existing fixed-binding behavior. Imported provenance permits a unique compatible current profile, otherwise the existing anonymous reader, otherwise an unavailable retained definition. Compare the complete normalized site URL and engine, not just the hostname.

Creating hidden saved profiles was rejected because it changes account state and grants capabilities. A parallel Topic model/store was rejected because source-aware Topic rendering and refresh already exist. Public access remains a current policy decision, never a property granted by the imported file.

## Implementation sequence

### Portable identity and read resolution

Extend `lib/core/search/following_topics/src/types/following_topic_source.dart` with backward-compatible imported profile identity/name. Update `following_topic_config_provider.dart` to distinguish portable imports from deliberately fixed local copies. Preserve imported reference identity in `lib/core/backups/sources/search_backup_profile.dart` on export.

Regression cases: old source JSON, credential stripping, full-site mismatch, unknown engine, no profiles, a unique compatible profile added/removed, duplicate accounts, existing fixed account bindings, policy revocation and no saved-profile creation.

### Import persistence and matching

Update `FollowingTopicImportService` so a missing profile stores a source-bearing Topic rather than throwing or skipping. Match a repeated portable import by original source reference, exact source identity, query and existing destination rules; do not merge independent copies or different accounts/sites. Existing successfully mapped imports retain their established path.

Use a fresh, collision-checked UUID storage namespace for a detached Topic, never the foreign profile UUID. The existing aggregate restore API may populate this new empty namespace only, inside the caller's serialized import transaction; never replace an existing profile bucket to attach provenance. Register newly allocated IDs before writing so rollback can remove partial creations. Preserve names, query structure, Auto-update, UUID conflict handling, folder actions and read-only mirror guards.

Regression cases: empty profile list, private/unknown sites, repeated import, duplicate Topics in different folders, explicit Copy, UUID/namespace conflicts, disabled updates, failed writes, Replace rollback, export/reimport and later profile appearance without duplicates. No network calls during import.

### Package preflight and preview parity

`ProfileDependencyPlanner` must treat references used only by `pinned_searches` as optional, without weakening real profile imports or legacy feed dependencies. A reference shared with a required source remains required. Do not invent a resolved profile ID for detached records.

`ImportPlannedChangeProjector.followingTopics` must accept absent profile mappings and use the same portable matching and new-Topic construction as execution. Check `ImportFlowNotifier` item recommendations and actual `PackageTransactionSource` application. Keep preview counts, Copy/Skip/folder selection, transaction revision checks and rollback consistent. Legacy raw restore preflight must stop asking permission to discard valid Topic definitions.

### UI and local acceptance

Exercise existing source-aware cards, opening, manual/automatic refresh, folder-feed history and export. Unavailable definitions must remain visible, manageable and exportable; opening must not clear NEW when no reader exists. Verify profile filters and badges for detached Topics and edit/remap behavior after a profile appears. Reuse Kurumi presentation and existing localized unavailable states; author any needed new strings in en-US only.

## Verification

Write focused regression tests before changing behavior. This remote environment has no FVM/Flutter/Dart toolchain; source inspection is not a passing test result. Run relevant tests locally using FVM, then the complete suite on the final integration candidate under AGENTS.md. Add narrow-width/enlarged-text widget coverage for affected unavailable/edit flows. Use a device only where native UI integration genuinely requires it.

Issue #187 remains the task/status authority. The final handoff must identify exactly what is implemented, what remains, the published commit, executed checks and unrun checks. No PR, merge, issue closure or branch deletion is authorized by this work.
