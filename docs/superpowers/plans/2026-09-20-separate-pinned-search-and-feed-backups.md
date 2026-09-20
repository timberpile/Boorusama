# Separate Pinned Search and Following Feed Backups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Pinned Searches and Following Feeds independent version 1 exports and imports, with feed imports replacing matching definitions.

**Architecture:** Keep the shared runtime search repository, but give each feature its own backup model, codec, source, importer, and result count. Share only portable profile matching, envelope validation, and the multi-source preflight; import profiles before either dependent source.

**Tech Stack:** Dart, Flutter, Riverpod, Hive CE, JSON backup sources, ZIP and device transfer, Flutter tests, Maestro for Android UI checks.

**Spec:** `docs/superpowers/specs/2026-09-20-separate-pinned-search-and-feed-backups-design.md`

## Global Constraints

- Source IDs are `pinned_searches` and `following_feeds`; each JSON envelope requires its matching `source` and `version: 1`.
- Accept only source format version 1 for each new source. Do not add migration code for experimental older exports. Leave the ZIP manifest version unchanged.
- Export definitions and portable profile references only. Never export internal search IDs, post/cache data, refresh state, errors, or NEW state.
- A same-UUID feed in the mapped profile replaces its name, order, and exact query membership. A wrong-owner UUID fails feed import before writes.
- Profile imports precede both dependent imports. A failure in one dependent source does not block the other.
- Use `fvm` for Flutter/Dart commands and `./gen.sh` after translation changes. Do not read or commit `.test_credentials` for these tests.
- Follow `AGENTS.md` and `docs/development_workflow.md`; keep unrelated changes out of commits.

## File map

| Responsibility | Files |
| --- | --- |
| Shared portable identity and envelope check | Create `lib/core/backups/sources/search_backup_profile.dart`, `search_backup_envelope.dart`; modify `pinned_search_backup_data.dart`, `pinned_search_import_service.dart`, `booru_configs_source.dart` |
| Independent payloads | Modify `pinned_search_backup_codec.dart`, `pinned_search_backup_data.dart`; create `following_feed_backup_data.dart`, `following_feed_backup_codec.dart` |
| Feed replacement and order | Create `following_feed_import_service.dart`; modify `search_following_feed.dart`, `search_subscription_repository.dart`, `search_subscription_repository_hive.dart` |
| Registered backup sources and copy | Modify `pinned_searches_source.dart`, `providers.dart`, `types/types.dart`, `packages/i18n/translations/en-US.json`, `docs/pinned_searches.md`; create `following_feeds_source.dart` |
| Preflight and visible prompt | Replace `pinned_search_import_preflight.dart` with `search_backup_import_preflight.dart`; replace `pinned_search_missing_profiles_dialog.dart` with `search_backup_missing_profiles_dialog.dart` |
| ZIP and device orchestration | Modify `zip/bulk_backup_service.dart`, `transfer/import/import_data_notifier.dart`; use the source registry for separate selection |
| Tests | Modify `test/core/backups/pinned_search_backup_codec_test.dart`, `pinned_search_import_service_test.dart`, `pinned_searches_source_test.dart`; create `search_backup_contract_test.dart`, `following_feed_backup_codec_test.dart`, `following_feed_import_service_test.dart`, `following_feeds_source_test.dart`; extend existing ZIP/device import tests in `pinned_searches_source_test.dart` and `server_import_context_test.dart` |

## Review Focus

These five inputs are easy to miss; each gets an explicit test in the named task.

1. A file with the wrong `source` or an unsupported version must fail before any writes (Task 1 and Task 4).
2. An empty Following Feeds export must round-trip as zero feeds (Task 2).
3. Replacing a feed after **adding** a query must invalidate its old post cache while reused member searches retain state (Task 3).
4. Profile matches that become ambiguous while a confirmation dialog is open must cancel without writes (Task 5).
5. A bad Pinned Searches file inside a ZIP must not prevent a valid Following Feeds source from importing when profiles succeeded (Task 6).

---

### Task 1: Shared backup identity and strict envelope contract

**Files:**
- Create: `lib/core/backups/sources/search_backup_profile.dart`, `lib/core/backups/sources/search_backup_envelope.dart`
- Modify: `lib/core/backups/sources/pinned_search_backup_data.dart`, `pinned_search_backup_codec.dart`, `pinned_search_import_service.dart`, `pinned_searches_source.dart`, `booru_configs_source.dart`
- Test: `test/core/backups/search_backup_contract_test.dart`, `pinned_search_backup_codec_test.dart`, `pinned_search_import_service_test.dart`, `pinned_searches_source_test.dart`

**Interfaces:**
- Produces: `BackupProfileReference` with `toJson()`, `parseBackupProfile(Object?, String)`, `normalizeBackupProfileUrl(String)`, `resolveBackupProfile(BackupProfileReference, List<BooruConfig>)`, `requireSearchBackupEnvelope(ExportDataPayload, String)`.
- Consumes: `normalizeBooruSiteUrl`, `InvalidBackupFormatException`, and existing `BooruConfig` identity fields.

- [ ] **Step 1: Write contract and matching tests.** Use `ExportDataPayload(version: 1, exportDate: null, exportVersion: null, data: const [], extraFields: const {'source': 'following_feeds'})` as the accepted case. Loop over wrong source, absent source, and version 2; assert `InvalidBackupFormatException`. Add matching cases for same ID/type/URL, unique type/URL after ID change, and ambiguous type/URL.

```dart
expect(() => requireSearchBackupEnvelope(valid, 'following_feeds'), returnsNormally);
expect(
  () => requireSearchBackupEnvelope(unsupportedVersion, 'following_feeds'),
  throwsA(isA<InvalidBackupFormatException>()),
);
```

- [ ] **Step 2: Run the new test and confirm it fails because the helpers are absent.**

```bash
fvm flutter test test/core/backups/search_backup_contract_test.dart
```

- [ ] **Step 3: Move the existing portable profile type, URL normalization, and `_resolveProfile` rule into the shared helper. Include the current profile field parser and JSON encoder there. Update imports and constructors in production code and tests. Add the envelope check without yet changing the active combined source.**

```dart
void requireSearchBackupEnvelope(ExportDataPayload payload, String sourceId) {
  if (payload.version != 1) {
    throw InvalidBackupFormatException('Unsupported $sourceId backup version');
  }
  if (payload.extraFields['source'] != sourceId) {
    throw InvalidBackupFormatException('Expected $sourceId backup source');
  }
}

BooruConfig? resolveBackupProfile(
  BackupProfileReference reference,
  List<BooruConfig> profiles,
) {
  final matches = profiles.where((profile) =>
      profile.auth.booruType.name == reference.booruType &&
      normalizeBackupProfileUrl(profile.url) ==
          normalizeBackupProfileUrl(reference.url)).toList();
  return matches.where((profile) => profile.id == reference.id).firstOrNull ??
      (matches.length == 1 ? matches.single : null);
}

BackupProfileReference parseBackupProfile(Object? raw, String field) {
  if (raw is! Map<String, dynamic>) {
    throw InvalidBackupFormatException('$field must be an object');
  }
  final id = raw['id'];
  final type = raw['booruType'];
  final url = raw['url'];
  final name = raw['name'];
  if (id is! int || id < 0 || type is! String || type.trim().isEmpty ||
      url is! String || name is! String || name.trim().isEmpty) {
    throw InvalidBackupFormatException('$field is invalid');
  }
  final uri = Uri.tryParse(url);
  if (uri == null || !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty) {
    throw InvalidBackupFormatException('$field.url is invalid');
  }
  return BackupProfileReference(
    id: id,
    booruType: type,
    url: normalizeBackupProfileUrl(url),
    name: name,
  );
}
```

- [ ] **Step 4: Format and run the new and existing pinned import tests.**

```bash
fvm dart format lib/core/backups/sources/search_backup_profile.dart lib/core/backups/sources/search_backup_envelope.dart lib/core/backups/sources/pinned_search_backup_data.dart lib/core/backups/sources/pinned_search_backup_codec.dart lib/core/backups/sources/pinned_search_import_service.dart lib/core/backups/sources/pinned_searches_source.dart lib/core/backups/sources/booru_configs_source.dart test/core/backups/search_backup_contract_test.dart test/core/backups/pinned_search_backup_codec_test.dart test/core/backups/pinned_search_import_service_test.dart test/core/backups/pinned_searches_source_test.dart
fvm flutter test test/core/backups/search_backup_contract_test.dart test/core/backups/pinned_search_backup_codec_test.dart test/core/backups/pinned_search_import_service_test.dart test/core/backups/pinned_searches_source_test.dart
```

- [ ] **Step 5: Commit only this extraction and its tests.**

```bash
git add lib/core/backups/sources/search_backup_profile.dart lib/core/backups/sources/search_backup_envelope.dart lib/core/backups/sources/pinned_search_backup_data.dart lib/core/backups/sources/pinned_search_backup_codec.dart lib/core/backups/sources/pinned_search_import_service.dart lib/core/backups/sources/pinned_searches_source.dart lib/core/backups/sources/booru_configs_source.dart test/core/backups/search_backup_contract_test.dart test/core/backups/pinned_search_backup_codec_test.dart test/core/backups/pinned_search_import_service_test.dart test/core/backups/pinned_searches_source_test.dart
git diff --cached --check
git commit -m "refactor(backups): share portable search profile matching"
```

### Task 2: Following Feeds v1 data and codec

**Files:**
- Create: `lib/core/backups/sources/following_feed_backup_data.dart`, `lib/core/backups/sources/following_feed_backup_codec.dart`
- Test: `test/core/backups/following_feed_backup_codec_test.dart`

**Interfaces:**
- Consumes: `BackupProfileReference`, `requireSearchBackupEnvelope`, `normalizeSearchIdentity`, and `followingFeedSourceLimit`.
- Produces: `FollowingFeedBackupData(List<FollowingFeedBackupRecord> feeds)` and `FollowingFeedBackupCodec extends JsonHandler<FollowingFeedBackupData>` with a private `parseFollowingFeedRow(Object?)` parser.

- [ ] **Step 1: Write failing codec tests for an ordered two-query feed, a zero-feed payload, duplicate normalized queries, wrong/missing source, unsupported version 2, a `search` row, malformed profile/UUID/position, and 1001 queries.** Assert that `encode` contains only feed definitions and never `sourceIds`, `posts`, or NEW state.

```dart
final parsed = codec.parse(ExportDataPayload(
  version: 1,
  exportDate: null,
  exportVersion: null,
  extraFields: const {'source': 'following_feeds'},
  data: [feedRow],
));
expect(parsed.feeds.single.queries, ['cat', 'dog']);
```

- [ ] **Step 2: Run the codec test and confirm it fails because the codec is absent.**

```bash
fvm flutter test test/core/backups/following_feed_backup_codec_test.dart
```

- [ ] **Step 3: Add immutable feed records and a codec that checks the envelope first, accepts only `kind: feed`, validates all fields, and normalizes queries in first-seen order.** Reuse the profile parser/validation extracted in Task 1; keep the per-feed limit at 1000.

```dart
@override
FollowingFeedBackupData parse(ExportDataPayload payload) {
  requireSearchBackupEnvelope(payload, 'following_feeds');
  return FollowingFeedBackupData(feeds: [
    for (final row in payload.data)
      parseFollowingFeedRow(row),
  ]);
}

FollowingFeedBackupRecord parseFollowingFeedRow(Object? raw) {
  if (raw is! Map<String, dynamic> || raw['kind'] != 'feed') {
    throw const InvalidBackupFormatException('Expected a feed row');
  }
  final id = raw['id'];
  final name = raw['name'];
  final position = raw['position'];
  final values = raw['queries'];
  if (id is! String || !Uuid.isValidUUID(fromString: id) ||
      name is! String || name.trim().isEmpty ||
      position is! int || position < 0 ||
      values is! List || values.isEmpty ||
      values.length > followingFeedSourceLimit ||
      values.any((value) => value is! String || value.trim().isEmpty)) {
    throw const InvalidBackupFormatException('Invalid feed row');
  }
  return FollowingFeedBackupRecord(
    id: id.toLowerCase(),
    name: name.trim(),
    position: position,
    queries: values.cast<String>().map(normalizeSearchIdentity).toSet().toList(),
    profile: parseBackupProfile(raw['profile'], 'feed.profile'),
  );
}

@override
List<dynamic> encode(FollowingFeedBackupData data) => [
  for (final feed in data.feeds)
    {
      'kind': 'feed',
      'id': feed.id,
      'name': feed.name,
      'position': feed.position,
      'queries': feed.queries,
      'profile': feed.profile.toJson(),
    },
];
```

`parseFollowingFeedRow(Object?)` is private to this codec. It rejects a non-map row, wrong kind, invalid UUID, blank name, negative/non-integer position, invalid profile, empty/non-string query, and lists longer than `followingFeedSourceLimit`. It calls Task 1's `parseBackupProfile(row['profile'], 'feed.profile')` and uses `BackupProfileReference.toJson()` for encoding.

- [ ] **Step 4: Format, run the codec tests, and commit.**

```bash
fvm dart format lib/core/backups/sources/following_feed_backup_data.dart lib/core/backups/sources/following_feed_backup_codec.dart test/core/backups/following_feed_backup_codec_test.dart
fvm flutter test test/core/backups/following_feed_backup_codec_test.dart test/core/backups/search_backup_contract_test.dart
git add lib/core/backups/sources/following_feed_backup_data.dart lib/core/backups/sources/following_feed_backup_codec.dart test/core/backups/following_feed_backup_codec_test.dart
git diff --cached --check
git commit -m "feat(backups): define following feed version one payload"
```

### Task 3: Replace imported feed definitions without losing unrelated state

**Files:**
- Create: `lib/core/backups/sources/following_feed_import_service.dart`
- Modify: `lib/core/search/subscriptions/src/types/search_following_feed.dart`, `lib/core/search/subscriptions/src/types/search_subscription_repository.dart`, `lib/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart`
- Test: `test/core/backups/following_feed_import_service_test.dart`, `test/core/search/subscriptions/following_feed_test.dart`

**Interfaces:**
- Consumes: `FollowingFeedBackupData`, `resolveBackupProfile`, `SearchSubscriptionRepository.saveFeed`, `getFeeds`, and `getAll`.
- Produces: `FollowingFeedImportService.preview(data, profiles: profiles)`, `apply(data, profiles: profiles, allowMissingProfiles: false)`, `FollowingFeedImportResult`, `FeedBackupIdConflictException(Set<String> ids)`, and `SearchSubscriptionRepository.setFeedOrder(int profileId, List<String> orderedIds)`.

- [ ] **Step 1: Write failing tests for same-ID query replacement, same-name/different-ID feeds, wrong-owner UUID conflict before writes, repeated import, unresolved profiles, order with existing local feeds, and rollback when a feed save fails.** Add a repository test showing that adding a query clears cached posts but keeps the old member source ID and runtime state; removing a query preserves a source still referenced by another feed.

```dart
await service.apply(changedBackup, profiles: [profile]);
final feed = (await repository.getFeeds()).single;
final searches = {for (final search in await repository.getAll()) search.id: search};
expect(feed.sourceIds.map((id) => searches[id]!.query).toList(), ['cat', 'bird']);
expect(feed.posts, isEmpty);
expect(await repository.getById(unchangedSourceId), isNotNull);
```

- [ ] **Step 2: Run the focused tests and verify the new behavior fails.**

```bash
fvm flutter test test/core/backups/following_feed_import_service_test.dart test/core/search/subscriptions/following_feed_test.dart
```

- [ ] **Step 3: Make `saveFeed` clear posts whenever query membership changes, not only when a query is removed. Add `position` to `SearchFollowingFeed.copyWith` and implement `setFeedOrder` as one serialized repository operation that validates the complete profile feed ID set, writes positions 0..N-1, and restores previous rows on an ordinary write failure.**

```dart
final membershipChanged = previous != null &&
    !const SetEquality<String>().equals(previous.sourceIds.toSet(), retainedIds);
final feed = SearchFollowingFeed(
  id: feedId,
  profileId: profileId,
  name: name.trim(),
  position: previous?.position ?? feeds.where((f) => f.profileId == profileId).length,
  sourceIds: retained.map((source) => source.id).toList(),
  posts: membershipChanged ? const [] : previous?.posts ?? const [],
);
```

- [ ] **Step 4: Implement preview and apply. Resolve all profiles and detect wrong-owner UUIDs before the first feed write. For each accepted row, call `saveFeed(id: record.id, ...)` so unchanged internal sources are reused. Compute each profile's final order by removing imported IDs from local order, sorting import rows by `(position, rowIndex)`, inserting at a clamped position after prior equal-position imports, then call `setFeedOrder`.** Treat an unchanged same-ID definition as already existing; count changed replacements and new feeds as imported.

```dart
final conflicts = data.feeds.where((record) {
  final target = resolveBackupProfile(record.profile, profiles);
  final local = localById[record.id];
  return target != null && local != null && local.profileId != target.id;
}).toList();
if (conflicts.isNotEmpty) throw FeedBackupIdConflictException(conflicts.map((e) => e.id).toSet());
```

- [ ] **Step 5: Format, run the focused tests, and commit.**

```bash
fvm dart format lib/core/backups/sources/following_feed_import_service.dart lib/core/search/subscriptions/src/types/search_following_feed.dart lib/core/search/subscriptions/src/types/search_subscription_repository.dart lib/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart test/core/backups/following_feed_import_service_test.dart test/core/search/subscriptions/following_feed_test.dart
fvm flutter test test/core/backups/following_feed_import_service_test.dart test/core/search/subscriptions/following_feed_test.dart
git add lib/core/backups/sources/following_feed_import_service.dart lib/core/search/subscriptions/src/types/search_following_feed.dart lib/core/search/subscriptions/src/types/search_subscription_repository.dart lib/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart test/core/backups/following_feed_import_service_test.dart test/core/search/subscriptions/following_feed_test.dart
git diff --cached --check
git commit -m "feat(backups): replace matching following feed definitions"
```

### Task 4: Register two independent v1 sources and separate the visible entries

**Files:**
- Create: `lib/core/backups/sources/following_feeds_source.dart`
- Modify: `lib/core/backups/sources/pinned_searches_source.dart`, `pinned_search_backup_codec.dart`, `pinned_search_backup_data.dart`, `pinned_search_import_service.dart`, `providers.dart`, `lib/core/backups/types/types.dart`, `packages/i18n/translations/en-US.json`, `docs/pinned_searches.md`
- Test: `test/core/backups/pinned_search_backup_codec_test.dart`, `pinned_search_import_service_test.dart`, `pinned_searches_source_test.dart`, `following_feeds_source_test.dart`

**Interfaces:**
- Consumes: both codecs/import services, `JsonBackupSource.extraPayloadEncoder`, `BackupOperationResult`, and existing `searchSubscriptionsProvider.notifier.runSerializedMutation`.
- Produces: registered `PinnedSearchesBackupSource(id: 'pinned_searches', version: 1)` and `FollowingFeedsBackupSource(id: 'following_feeds', version: 1)`; separate `feedCount` in `BackupOperationResult`.

- [ ] **Step 1: Update failing source and codec tests.** Assert both registry IDs, distinct GET endpoints/file names, separate count texts, strict headers, an empty pinned export with its organization row, Pinned Searches output with no `feed` row/internal IDs, Following Feeds output in `sourceIds` query order with no cache/runtime fields, and export failure for a feed referencing a missing internal source. Replace old tests that intentionally round-trip combined data with one test in each new suite.

```dart
expect(registry.getSource('pinned_searches'), isNotNull);
expect(registry.getSource('following_feeds'), isNotNull);
expect(jsonDecode(pinnedJson)['version'], 1);
expect(jsonDecode(feedJson)['source'], 'following_feeds');
```

- [ ] **Step 2: Run the source and codec tests and confirm they fail on the current combined source.**

```bash
fvm flutter test test/core/backups/pinned_search_backup_codec_test.dart test/core/backups/following_feeds_source_test.dart test/core/backups/pinned_searches_source_test.dart
```

- [ ] **Step 3: Remove `feeds` from `PinnedSearchBackupData`, codec, and importer. Require explicit `kind: search`, `kind: folder`, and one `kind: organization` row. Require the pinned envelope at parse time. Set source version 1 and `extraPayloadEncoder: (_) => const {'source': 'pinned_searches'}`. Keep current independent-pin merge and folder mapping.**

```dart
PinnedSearchBackupData parse(ExportDataPayload payload) {
  requireSearchBackupEnvelope(payload, 'pinned_searches');
  return _parseIndependentPinsAndOrganization(payload.data);
}
```

`_parseIndependentPinsAndOrganization(List<dynamic>)` is the existing parse loop moved to a private method in this codec; it retains the current UUID, folder-name, and membership validation. Change the encoder to write `kind: search` on every search row and never write a feed row.

- [ ] **Step 4: Add `FollowingFeedsBackupSource` with its own dataGetter, codec, importer, result count, and tile. In the getter, index subscriptions by ID and map each feed's `sourceIds` in their stored order. Register it beside the pinned source; add `feedCount` to `BackupOperationResult` and feed-specific localized messages.**

```dart
final subscriptionsById = {
  for (final search in await repository.getAll()) search.id: search,
};
final queries = [
  for (final sourceId in feed.sourceIds)
    switch (subscriptionsById[sourceId]) {
      final source? => source.query,
      null => throw StateError('Missing feed source $sourceId'),
    },
];
```

Fail export if a stored feed references a missing internal source instead of silently exporting a shortened definition. Set the new source's `extraPayloadEncoder` to `{'source': 'following_feeds'}`. Derive each tile's count from independent subscriptions or feeds respectively; use `context.t` for all visible text. Add the separate backup contract to `docs/pinned_searches.md`.

- [ ] **Step 5: Generate, format, run focused tests, and commit.**

```bash
./gen.sh
fvm dart format lib/core/backups/sources/pinned_searches_source.dart lib/core/backups/sources/following_feeds_source.dart lib/core/backups/sources/pinned_search_backup_codec.dart lib/core/backups/sources/pinned_search_backup_data.dart lib/core/backups/sources/pinned_search_import_service.dart lib/core/backups/sources/providers.dart lib/core/backups/types/types.dart test/core/backups/pinned_search_backup_codec_test.dart test/core/backups/pinned_search_import_service_test.dart test/core/backups/pinned_searches_source_test.dart test/core/backups/following_feeds_source_test.dart
fvm flutter test test/core/backups/pinned_search_backup_codec_test.dart test/core/backups/pinned_search_import_service_test.dart test/core/backups/pinned_searches_source_test.dart test/core/backups/following_feeds_source_test.dart
git add lib/core/backups/sources/pinned_searches_source.dart lib/core/backups/sources/following_feeds_source.dart lib/core/backups/sources/pinned_search_backup_codec.dart lib/core/backups/sources/pinned_search_backup_data.dart lib/core/backups/sources/pinned_search_import_service.dart lib/core/backups/sources/providers.dart lib/core/backups/types/types.dart packages/i18n/translations/en-US.json docs/pinned_searches.md test/core/backups/pinned_search_backup_codec_test.dart test/core/backups/pinned_search_import_service_test.dart test/core/backups/pinned_searches_source_test.dart test/core/backups/following_feeds_source_test.dart
git add packages/i18n/lib/src/locales.dart
git diff --cached --check
git commit -m "feat(backups): split pinned searches and following feeds"
```

### Task 5: Preview unresolved profiles for standalone and combined imports

**Files:**
- Create: `lib/core/backups/sources/search_backup_import_preflight.dart`, `lib/core/backups/widgets/search_backup_missing_profiles_dialog.dart`
- Modify: `lib/core/backups/sources/pinned_searches_source.dart`, `following_feeds_source.dart`, `packages/i18n/translations/en-US.json`
- Remove: `lib/core/backups/sources/pinned_search_import_preflight.dart`, `lib/core/backups/widgets/pinned_search_missing_profiles_dialog.dart`
- Test: `test/core/backups/pinned_searches_source_test.dart`, `following_feeds_source_test.dart`

**Interfaces:**
- Consumes: each import service's `preview`, `ImportPreparation.preparedData`, selected source IDs, and projected `List<BooruConfig>`.
- Produces: `SearchBackupImportApproval(Set<String> unmatchedRecordIds)` per source, `confirmSearchBackupProfiles({required Set<String> unmatchedRecordIds, required int pinnedCount, required int feedCount, required BuildContext? context})`, and `preflightSearchBackups(...) -> Map<String, SearchBackupImportApproval>` for ZIP/device flows. Each source's `approvedResultExecutor` rechecks its own set before mutation.

- [ ] **Step 1: Write failing tests for one-source pin warning, one-source feed warning, combined warning with separate counts, headless unresolved-profile failure, cancel/dismiss before writes, and profiles changing from matched to ambiguous while the dialog is open.**

```dart
expect(find.textContaining('1 pinned search'), findsOneWidget);
expect(find.textContaining('2 following feeds'), findsOneWidget);
expect(await repository.getFeeds(), beforeFeeds);
```

- [ ] **Step 2: Run both source suites and confirm the feed-specific/combined cases fail.**

```bash
fvm flutter test test/core/backups/pinned_searches_source_test.dart test/core/backups/following_feeds_source_test.dart
```

- [ ] **Step 3: Add `confirmSearchBackupProfiles` for the localized prompt, then shared preflight that selects projected profiles from prepared `profiles` when chosen, otherwise current profiles. Preview both prepared source payloads, call the prompt once with separate counts, and return per-source approvals. On headless unresolved data, cancellation, or a changed unresolved set, throw `ImportCancelledException` before mutation.**

```dart
final projectedProfiles = selectedIds.contains('profiles')
    ? prepared['profiles']?.preparedData as List<BooruConfig>
    : await currentProfiles();
final unmatchedPins = pinData == null
    ? <String>{}
    : pinService.preview(pinData, profiles: projectedProfiles).unmatchedRecordIds;
final unmatchedFeeds = feedData == null
    ? <String>{}
    : feedService.preview(feedData, profiles: projectedProfiles).unmatchedRecordIds;
```

Check the prepared profile payload's type before the cast; a selected but unprepared profile source blocks both dependent imports. Return one approval per prepared dependent source, including an empty set. The dialog shows source-specific counts and one Skip and import action. Recheck sets after the dialog and again in each approved executor.

- [ ] **Step 4: Replace the old pin-only dialog. For standalone import, each source previews against current profiles and calls `confirmSearchBackupProfiles` with the other source's count zero; its approved executor rechecks the set. For ZIP/device import, call `preflightSearchBackups`. Generate translations, format, run tests, and commit.**

```bash
./gen.sh
fvm dart format lib/core/backups/sources/search_backup_import_preflight.dart lib/core/backups/sources/pinned_searches_source.dart lib/core/backups/sources/following_feeds_source.dart lib/core/backups/widgets/search_backup_missing_profiles_dialog.dart test/core/backups/pinned_searches_source_test.dart test/core/backups/following_feeds_source_test.dart
fvm flutter test test/core/backups/pinned_searches_source_test.dart test/core/backups/following_feeds_source_test.dart
git add lib/core/backups/sources/search_backup_import_preflight.dart lib/core/backups/sources/pinned_searches_source.dart lib/core/backups/sources/following_feeds_source.dart lib/core/backups/widgets/search_backup_missing_profiles_dialog.dart packages/i18n/translations/en-US.json test/core/backups/pinned_searches_source_test.dart test/core/backups/following_feeds_source_test.dart
git add -u lib/core/backups/sources/pinned_search_import_preflight.dart lib/core/backups/widgets/pinned_search_missing_profiles_dialog.dart
git add packages/i18n/lib/src/locales.dart
git diff --cached --check
git commit -m "feat(backups): preview missing search and feed profiles"
```

### Task 6: Keep ZIP and device transfer independent after profile import

**Files:**
- Modify: `lib/core/backups/zip/bulk_backup_service.dart`, `lib/core/backups/transfer/import/import_data_notifier.dart`
- Test: `test/core/backups/pinned_searches_source_test.dart`, `test/core/backups/server_import_context_test.dart`

**Interfaces:**
- Consumes: `preflightSearchBackups`, its per-source approvals, `ImportPreparation.executeImport(approval: ...)`, and the registry's two source IDs.
- Produces: separate selected/imported/failed/skipped result entries for `pinned_searches` and `following_feeds` in ZIP and device transfer.

- [ ] **Step 1: Write failing ZIP/device tests for both selected sources, each source selected alone, an older ZIP without a feed entry, a pin source with an unsupported version alongside a valid feed source, a failed profile import blocking both dependents but allowing unrelated prepared sources, and a feed import failure that leaves a valid pin import runnable.**

```dart
expect(result.imported, contains('following_feeds'));
expect(result.failed, contains('pinned_searches'));
expect(result.failed, isNot(contains('following_feeds')));
```

- [ ] **Step 2: Run the two focused suites and confirm the new cases fail.**

```bash
fvm flutter test test/core/backups/pinned_searches_source_test.dart test/core/backups/server_import_context_test.dart
```

- [ ] **Step 3: Replace pin-only preflight calls with `preflightSearchBackups` in ZIP and device transfer. Ensure selected profiles execute first, pass `approvals[sourceId]` to each dependent `executeImport`, and track a failed profile source as a dependency failure for both dependents. Continue processing unrelated prepared sources and the other dependent when only one dependent fails.**

```dart
final approvals = await preflightSearchBackups(
  prepared: prepared,
  selectedIds: selectedIds,
  currentProfiles: () => ref.read(booruConfigRepoProvider).getAll(),
  context: uiContext,
);
for (final entry in prepared.entries) {
  if (profileFailed &&
      const {'pinned_searches', 'following_feeds'}.contains(entry.key)) {
    failed.add(entry.key);
    continue;
  }
  await entry.value.executeImport(
    deferRestart: true,
    approval: approvals[entry.key],
  );
}
```

Preserve each loop's existing per-source try/catch and restart deferral. If profile preparation fails before preflight, mark the two selected dependents failed and continue only unrelated sources. A source-format error during preparation marks only that source failed.

- [ ] **Step 4: Format, run focused tests, then run repository-wide verification and commit.**

```bash
fvm dart format lib/core/backups/zip/bulk_backup_service.dart lib/core/backups/transfer/import/import_data_notifier.dart test/core/backups/pinned_searches_source_test.dart test/core/backups/server_import_context_test.dart
fvm flutter test test/core/backups/pinned_searches_source_test.dart test/core/backups/server_import_context_test.dart
fvm flutter test
fvm flutter analyze
git add lib/core/backups/zip/bulk_backup_service.dart lib/core/backups/transfer/import/import_data_notifier.dart test/core/backups/pinned_searches_source_test.dart test/core/backups/server_import_context_test.dart
git diff --cached --check
git commit -m "fix(backups): import feed and pin sources independently"
```

## Final verification and handoff

- [ ] Use the available Android emulator through Maestro to inspect the backup picker, separate feed and pin counts, and the missing-profile import prompt. Do not claim an import flow was manually checked unless it was actually exercised.
- [ ] Check `git status --short --branch` and `git diff --check`; report automated and manual results separately.
- [ ] Request independent whole-branch review before a PR or merge. Do not push, open a PR, or merge without the user's explicit request.
