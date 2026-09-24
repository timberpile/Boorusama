# Bookmark Live Comparison Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a reproducible one-time comparison of 1,000 real Danbooru and Gelbooru V2 bookmarks on pinned `develop` and unified-post revisions, retaining the frozen post manifest and evidence report but no benchmark product code.

**Architecture:** Two isolated local comparison branches receive the same temporary Dev-only manifest parser, import coordinator, screen, and measurement markers. Only their post-loader adapter differs: `develop` uses `postRepoProvider`, while the feature revision uses `originAwarePostRepoProvider`; a retained 500/500 manifest and the normal `BookmarkRepository` make both runs use the same identities and real storage paths.

**Tech Stack:** Flutter/Dart with FVM, Riverpod without code generation, Hive CE, Android Dev flavor in profile mode, ADB, Maestro, SHA-256, repository-local `.test_credentials`.

**Spec:** `docs/superpowers/specs/2026-09-24-bookmark-live-comparison-design.md`

## Global Constraints

- Run both revisions sequentially on the same available Android emulator; use `emulator-5556` unless preflight shows that it is unavailable.
- Target `com.timberpile.boorusama.dev` explicitly for every package operation and pass the emulator ID to every ADB, Flutter, and Maestro operation.
- Pin and record the exact `origin/develop` and `feature/bookmark-post-behavior-parity` commits before collecting the manifest.
- The feature revision must include the provider-cardinality optimization and committed performance guards; never benchmark a dirty worktree.
- Use `fvm` for every Flutter and Dart command.
- Clear Dev app data and recreate exactly one Danbooru and one Gelbooru V2 profile before each revision.
- Read only the required records from `/home/timber/code/Boorusama/.test_credentials`; never print, log, commit, screenshot, or copy credential values into fixtures.
- Never mutate server favorites, votes, comments, tags, follows, or other shared remote account state.
- The retained manifest contains only schema, sequence, logical profile key, and numeric post ID.
- Import, retry, profile creation, media-cache preparation, and manifest validation are never included in measured timings.
- Do not merge the temporary importer, temporary page, instrumentation, asset declaration, tests, or comparison branches.
- Do not remove temporary branches or worktrees until the report is reviewed and the user explicitly approves cleanup.

## Review Focus

- A missing, deleted, or wrong-ID live response must stop preflight before the first bookmark write; Task 3 tests this with a missing response and a mismatched returned ID.
- A malformed, duplicate, non-contiguous, non-alternating, or uneven manifest must be rejected; Task 2 tests each input class.
- Missing or duplicate Danbooru/Gelbooru V2 profiles must stop setup without choosing an arbitrary profile; Task 4 tests zero and duplicate matches.
- A mid-import storage failure must remove every bookmark written by that run and verify an empty repository; Task 3 tests rollback success and rollback failure reporting.
- Automatic media loading must remain blocked during cold-load runs; Task 6 records that state in every marker and Task 7 rejects a cold run that does not report `mediaBlocked: true`.

## File Map

Retained on `feature/bookmark-post-behavior-parity`:

- `docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-manifest.json` — frozen 1,000-entry identity list.
- `docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-report.md` — hashes, environment, raw values, medians, functional observations, and conclusion.
- `docs/work/in-progress/QA-002-bookmark-live-comparison.md` — queue progress and evidence; moved to `done/` only after report review.

Temporary and identical on both comparison branches unless marked otherwise:

- `lib/core/developer_options/bookmark_live_benchmark/manifest.dart` — strict manifest values, JSON codec, digest, and structural validation.
- `lib/core/developer_options/bookmark_live_benchmark/importer.dart` — preflight, bounded loading, retry, ordered writes, rollback, and final verification.
- `lib/core/developer_options/bookmark_live_benchmark/runtime.dart` — profile resolution and application provider wiring.
- `lib/core/developer_options/bookmark_live_benchmark/post_loader.dart` — architecture-specific repository adapter; this is the only intentionally different harness file.
- `lib/core/developer_options/bookmark_live_benchmark/collector.dart` — deterministic candidate collection, coverage selection, and external manifest export.
- `lib/core/developer_options/bookmark_live_benchmark/metrics.dart` — structured non-sensitive marker format and measurement phase state.
- `lib/core/developer_options/bookmark_live_benchmark/page.dart` — Dev-only collect, validate, import, rollback, and status UI.
- `test/core/developer_options/bookmark_live_benchmark/manifest_test.dart` — manifest contract tests.
- `test/core/developer_options/bookmark_live_benchmark/importer_test.dart` — observable import and rollback tests.
- `test/core/developer_options/bookmark_live_benchmark/runtime_test.dart` — profile selection tests.
- `test/core/developer_options/bookmark_live_benchmark/collector_test.dart` — deterministic 500/500 selection and coverage tests.
- `test/core/developer_options/bookmark_live_benchmark/metrics_test.dart` — phase and marker tests.
- `lib/core/developer_options/widgets.dart` — temporary entry point.
- `lib/core/developer_options/l10n.dart` — temporary benchmark labels through `context.t`.
- `lib/core/bookmarks/src/providers/bookmark_provider.dart` — temporary repository-load marker.
- `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart` — temporary first-grid marker.
- `pubspec.yaml` — temporary manifest asset declaration after the manifest is frozen.

---

### Task 1: Pin revisions and create isolated comparison worktrees

**Files:**
- Verify: `/home/timber/code/Boorusama/.worktrees/bookmark-post-behavior-parity`
- Create worktree: `/home/timber/code/Boorusama/.worktrees/bookmark-live-feature`
- Create worktree: `/home/timber/code/Boorusama/.worktrees/bookmark-live-develop`
- Update progress: `docs/work/in-progress/QA-002-bookmark-live-comparison.md`

**Interfaces:**
- Consumes: a clean, fully committed feature revision and current `origin/develop`.
- Produces: two named local comparison branches and a revision record used by every later task.

- [ ] **Step 1: Finish or separately commit all existing feature work**

Run in the feature worktree:

```bash
git status --short
```

Expected: no output. If performance tests, provider optimization, architecture HTML, or task evidence are still uncommitted, finish and commit them in focused conventional commits before continuing. Do not fold them into a benchmark-harness commit.

- [ ] **Step 2: Fetch and pin both revisions**

Run:

```bash
git fetch origin develop
BOOKMARK_DEVELOP_SHA="$(git rev-parse origin/develop)"
BOOKMARK_FEATURE_SHA="$(git rev-parse feature/bookmark-post-behavior-parity)"
git show -s --format='%H %ci %s' "$BOOKMARK_DEVELOP_SHA"
git show -s --format='%H %ci %s' "$BOOKMARK_FEATURE_SHA"
```

Expected: two full hashes and commit subjects. Copy both exact lines into the queue task under a `Pinned revisions` subsection.

- [ ] **Step 3: Create comparison-only branches and worktrees**

Run from the main repository:

```bash
git worktree add -b feature/bookmark-live-harness-develop /home/timber/code/Boorusama/.worktrees/bookmark-live-develop "$BOOKMARK_DEVELOP_SHA"
git worktree add -b feature/bookmark-live-harness-feature /home/timber/code/Boorusama/.worktrees/bookmark-live-feature "$BOOKMARK_FEATURE_SHA"
```

Expected: each worktree is on its named local branch at the recorded revision. Do not push either branch.

- [ ] **Step 4: Bootstrap both worktrees**

Run in each worktree:

```bash
cd packages/boorusama_cli
fvm dart pub get
cd ../..
./gen.sh
fvm flutter test --no-pub test/core/bookmarks/bookmark_provider_test.dart
```

Expected: generation and the focused baseline test pass in both worktrees.

- [ ] **Step 5: Record environment identity**

Run:

```bash
fvm flutter --version
adb -s emulator-5556 shell getprop ro.build.version.release
adb -s emulator-5556 shell getprop ro.build.fingerprint
adb -s emulator-5556 shell pm path com.timberpile.boorusama.dev
```

Expected: Flutter version, Android version/fingerprint, and either the currently installed Dev package path or a clear `package not found` result. Add these values, without credentials, to the queue task.

- [ ] **Step 6: Commit only the queue revision record**

Run in the original feature worktree:

```bash
git add docs/work/in-progress/QA-002-bookmark-live-comparison.md
git diff --cached --check
git commit -m "docs(bookmarks): pin live comparison revisions"
```

Expected: one documentation-only commit.

### Task 2: Implement and prove the strict manifest contract

**Files:**
- Create: `lib/core/developer_options/bookmark_live_benchmark/manifest.dart`
- Create: `test/core/developer_options/bookmark_live_benchmark/manifest_test.dart`

**Interfaces:**
- Produces: `BenchmarkProfile`, `BookmarkLiveEntry`, and `BookmarkLiveManifest.parse(String source)`.
- Produces: `String BookmarkLiveManifest.toCanonicalJson()` and `Digest BookmarkLiveManifest.digest`.
- Consumed by: Tasks 3–7.

- [ ] **Step 1: Write failing structural tests**

Create `manifest_test.dart` with a helper that generates canonical maps, then add parameterized tests proving:

```dart
expect(manifest.entries, hasLength(1000));
expect(
  manifest.entries.where((entry) => entry.profile == BenchmarkProfile.danbooru),
  hasLength(500),
);
expect(manifest.entries.indexed.every((pair) {
  final (index, entry) = pair;
  return entry.sequence == index &&
      entry.profile ==
          (index.isEven
              ? BenchmarkProfile.danbooru
              : BenchmarkProfile.gelbooruV2);
}), isTrue);
expect(manifest.digest.toString(), sha256.convert(utf8.encode(manifest.toCanonicalJson())).toString());
```

Add one case per invalid input: wrong schema version, count 999, unequal profile counts, duplicate `(profile, postId)`, zero/negative ID, skipped sequence, repeated sequence, unknown profile, non-alternating profiles, and unexpected entry fields.

- [ ] **Step 2: Run the test and verify the red state**

Run in `bookmark-live-feature`:

```bash
fvm flutter test --no-pub test/core/developer_options/bookmark_live_benchmark/manifest_test.dart
```

Expected: compilation fails because the manifest types do not exist.

- [ ] **Step 3: Implement strict immutable values**

Implement these public shapes in `manifest.dart`:

```dart
enum BenchmarkProfile {
  danbooru('danbooru', BooruType.danbooru),
  gelbooruV2('gelbooru_v2', BooruType.gelbooruV2);

  const BenchmarkProfile(this.key, this.booruType);
  final String key;
  final BooruType booruType;

  static BenchmarkProfile parse(String value) => switch (value) {
    'danbooru' => BenchmarkProfile.danbooru,
    'gelbooru_v2' => BenchmarkProfile.gelbooruV2,
    _ => throw FormatException('Unknown benchmark profile: $value'),
  };
}

final class BookmarkLiveEntry extends Equatable {
  const BookmarkLiveEntry({
    required this.sequence,
    required this.profile,
    required this.postId,
  });

  final int sequence;
  final BenchmarkProfile profile;
  final int postId;

  @override
  List<Object> get props => [sequence, profile, postId];
}

final class BookmarkLiveManifest {
  const BookmarkLiveManifest._(this.entries);

  static const schemaVersion = 1;
  static const entriesPerProfile = 500;
  final List<BookmarkLiveEntry> entries;

  static BookmarkLiveManifest parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 2 ||
        decoded['schemaVersion'] != schemaVersion ||
        decoded['entries'] is! List<dynamic>) {
      throw const FormatException('Invalid bookmark benchmark envelope');
    }
    final keys = decoded.keys.toSet();
    if (!keys.containsAll(const {'schemaVersion', 'entries'})) {
      throw const FormatException('Unexpected bookmark benchmark fields');
    }

    final entries = <BookmarkLiveEntry>[];
    for (final (index, value) in
        (decoded['entries'] as List<dynamic>).indexed) {
      if (value is! Map<String, dynamic> || value.length != 3) {
        throw FormatException('Invalid entry at index $index');
      }
      final entryKeys = value.keys.toSet();
      if (!entryKeys.containsAll(const {'sequence', 'profile', 'postId'})) {
        throw FormatException('Unexpected entry fields at index $index');
      }
      final sequence = value['sequence'];
      final profile = value['profile'];
      final postId = value['postId'];
      if (sequence is! int || profile is! String || postId is! int) {
        throw FormatException('Invalid entry values at index $index');
      }
      entries.add(
        BookmarkLiveEntry(
          sequence: sequence,
          profile: BenchmarkProfile.parse(profile),
          postId: postId,
        ),
      );
    }

    if (entries.length != entriesPerProfile * 2) {
      throw const FormatException('Manifest must contain 1000 entries');
    }
    final identities = <(BenchmarkProfile, int)>{};
    for (final (index, entry) in entries.indexed) {
      final expectedProfile = index.isEven
          ? BenchmarkProfile.danbooru
          : BenchmarkProfile.gelbooruV2;
      if (entry.sequence != index ||
          entry.profile != expectedProfile ||
          entry.postId <= 0 ||
          !identities.add((entry.profile, entry.postId))) {
        throw FormatException('Invalid manifest entry at index $index');
      }
    }
    return BookmarkLiveManifest._(List.unmodifiable(entries));
  }

  String toCanonicalJson() => '${const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': schemaVersion,
    'entries': [
      for (final entry in entries)
        {
          'sequence': entry.sequence,
          'profile': entry.profile.key,
          'postId': entry.postId,
        },
    ],
  })}\n';

  Digest get digest => sha256.convert(utf8.encode(toCanonicalJson()));
}
```

Import `dart:convert`, `package:crypto/crypto.dart`, `package:equatable/equatable.dart`, and the repository export that defines `BooruType`; do not duplicate those types inside the harness.

The parser must pattern-match nullable external JSON explicitly, reject extra keys, create `List.unmodifiable`, and validate all invariants before returning.

- [ ] **Step 4: Format and prove green**

Run:

```bash
fvm dart format lib/core/developer_options/bookmark_live_benchmark/manifest.dart test/core/developer_options/bookmark_live_benchmark/manifest_test.dart
fvm flutter test --no-pub test/core/developer_options/bookmark_live_benchmark/manifest_test.dart
fvm flutter analyze --no-pub lib/core/developer_options/bookmark_live_benchmark/manifest.dart test/core/developer_options/bookmark_live_benchmark/manifest_test.dart
```

Expected: all manifest tests pass and analysis reports no issues.

- [ ] **Step 5: Commit the temporary manifest contract**

Run in `bookmark-live-feature`:

```bash
git add lib/core/developer_options/bookmark_live_benchmark/manifest.dart test/core/developer_options/bookmark_live_benchmark/manifest_test.dart
git diff --cached --check
git commit -m "test(bookmarks): add live manifest contract"
```

### Task 3: Implement preflight, ordered import, retry, rollback, and verification

**Files:**
- Create: `lib/core/developer_options/bookmark_live_benchmark/importer.dart`
- Create: `test/core/developer_options/bookmark_live_benchmark/importer_test.dart`

**Interfaces:**
- Consumes: `BookmarkLiveManifest` from Task 2.
- Produces: `BookmarkLiveImportCoordinator`, `BookmarkLiveImportProgress`, `BookmarkLiveImportResult`, and `BookmarkLiveImportException`.
- Injects: post load, bookmark write/read/remove, delay, and progress callbacks so unit tests never use network or Hive.

- [ ] **Step 1: Write failing observable behavior tests**

Use real lightweight `Post` and `Bookmark` fixture builders, but inject external operations. Cover these behaviors:

```dart
test('preflight resolves every post before the first bookmark write', () async {
  final events = <String>[];
  final result = await coordinator.run(
    manifest,
    onProgress: (progress) => events.add(progress.phase.name),
  );
  expect(events.indexOf('writing'), greaterThan(events.lastIndexOf('loading')));
  expect(result.writtenCount, 1000);
});

test('a missing post leaves storage untouched', () async {
  loadPost = (entry) async => entry.sequence == 731 ? null : postFor(entry);
  await expectLater(coordinator.run(manifest), throwsA(isA<BookmarkLiveImportException>()));
  expect(writeCalls, isEmpty);
});

test('a wrong returned id leaves storage untouched', () async {
  loadPost = (entry) async => postFor(entry, overrideId: entry.postId + 1);
  await expectLater(coordinator.run(manifest), throwsA(isA<BookmarkLiveImportException>()));
  expect(writeCalls, isEmpty);
});

test('a write failure removes all records written by the run', () async {
  writeBookmark = (entry, post) async {
    if (entry.sequence == 300) throw StateError('write failed');
    return storedBookmark(entry);
  };
  await expectLater(coordinator.run(manifest), throwsA(isA<BookmarkLiveImportException>()));
  expect(removedBookmarks.length, 300);
  expect(await readBookmarks(), isEmpty);
});
```

Also test three-attempt retry, no retry after success, rollback failure reporting, reversed write order for newest-first presentation, duplicate stored identity detection, wrong final count, and exact 500/500 final distribution.

- [ ] **Step 2: Run the importer test and verify the red state**

Run:

```bash
fvm flutter test --no-pub test/core/developer_options/bookmark_live_benchmark/importer_test.dart
```

Expected: compilation fails because the coordinator types are undefined.

- [ ] **Step 3: Implement the coordinator with injected boundaries**

Use these signatures:

```dart
typedef BookmarkLivePostLoader = Future<Post?> Function(BookmarkLiveEntry entry);
typedef BookmarkLiveWriter = Future<Bookmark> Function(
  BookmarkLiveEntry entry,
  Post post,
);
typedef BookmarkLiveReader = Future<List<Bookmark>> Function();
typedef BookmarkLiveRemover = Future<void> Function(Iterable<Bookmark> bookmarks);
typedef BookmarkLiveDelay = Future<void> Function(Duration duration);

final class BookmarkLiveImportCoordinator {
  BookmarkLiveImportCoordinator({
    required BookmarkLivePostLoader loadPost,
    required BookmarkLiveWriter writeBookmark,
    required BookmarkLiveReader readBookmarks,
    required BookmarkLiveRemover removeBookmarks,
    BookmarkLiveDelay? delay,
    int concurrency = 4,
  }) : _loadPost = loadPost,
       _writeBookmark = writeBookmark,
       _readBookmarks = readBookmarks,
       _removeBookmarks = removeBookmarks,
       _delay = delay ?? _defaultDelay,
       _concurrency = concurrency;

  final BookmarkLivePostLoader _loadPost;
  final BookmarkLiveWriter _writeBookmark;
  final BookmarkLiveReader _readBookmarks;
  final BookmarkLiveRemover _removeBookmarks;
  final BookmarkLiveDelay _delay;
  final int _concurrency;

  static Future<void> _defaultDelay(Duration duration) =>
      Future<void>.delayed(duration);

  Future<BookmarkLiveImportResult> run(
    BookmarkLiveManifest manifest, {
    required bool newestFirst,
    void Function(BookmarkLiveImportProgress progress)? onProgress,
  });
}
```

Load entries in chunks of four, retry only the failing entry at 500 ms and 1,500 ms, store resolved posts by entry identity, and do not invoke `writeBookmark` until all 1,000 identities are validated. On write failure, remove the exact returned bookmarks and then require `readBookmarks()` to be empty. Verify final stored identities by `(booruId, postId)` rather than media URL.

- [ ] **Step 4: Prove red-green rollback behavior explicitly**

Run the passing importer test, temporarily replace `await removeBookmarks(created)` with a no-op, rerun the named rollback test and observe failure, then restore the implementation and rerun:

```bash
fvm flutter test --no-pub test/core/developer_options/bookmark_live_benchmark/importer_test.dart --plain-name 'a write failure removes all records written by the run'
```

Expected: PASS only with rollback restored.

- [ ] **Step 5: Format, analyze, and commit**

Run:

```bash
fvm dart format lib/core/developer_options/bookmark_live_benchmark/importer.dart test/core/developer_options/bookmark_live_benchmark/importer_test.dart
fvm flutter test --no-pub test/core/developer_options/bookmark_live_benchmark/importer_test.dart
fvm flutter analyze --no-pub lib/core/developer_options/bookmark_live_benchmark/importer.dart test/core/developer_options/bookmark_live_benchmark/importer_test.dart
git add lib/core/developer_options/bookmark_live_benchmark/importer.dart test/core/developer_options/bookmark_live_benchmark/importer_test.dart
git diff --cached --check
git commit -m "test(bookmarks): add live import coordinator"
```

Expected: tests and analysis pass; the commit contains only coordinator code and tests.

### Task 4: Wire profiles, repositories, collection, and the temporary Dev page

**Files:**
- Create: `lib/core/developer_options/bookmark_live_benchmark/runtime.dart`
- Create: `lib/core/developer_options/bookmark_live_benchmark/post_loader.dart`
- Create: `lib/core/developer_options/bookmark_live_benchmark/collector.dart`
- Create: `lib/core/developer_options/bookmark_live_benchmark/page.dart`
- Create: `test/core/developer_options/bookmark_live_benchmark/runtime_test.dart`
- Create: `test/core/developer_options/bookmark_live_benchmark/collector_test.dart`
- Modify: `lib/core/developer_options/widgets.dart`
- Modify: `lib/core/developer_options/l10n.dart`

**Interfaces:**
- Consumes: manifest and coordinator from Tasks 2–3.
- Produces: `BookmarkLiveProfiles.resolve(List<BooruConfig>)`, `BookmarkLivePostLoaderAdapter`, `BookmarkLiveManifestCollector`, and `BookmarkLiveBenchmarkPage`.
- Produces: `Future<Post?> load(BookmarkLiveEntry entry)` and `Future<List<Post>> loadPage(BenchmarkProfile profile, int page, {int limit = 100})` on `BookmarkLivePostLoaderAdapter`.
- The feature adapter consumes `originAwarePostRepoProvider(config)`; Task 6 replaces only this adapter for `develop`.

- [ ] **Step 1: Write failing profile-resolution tests**

Test exact matching by `BooruType`, not display name or local ID:

```dart
expect(
  BookmarkLiveProfiles.resolve([danbooruConfig, gelbooruV2Config]),
  BookmarkLiveProfiles(
    danbooru: danbooruConfig,
    gelbooruV2: gelbooruV2Config,
  ),
);
expect(
  () => BookmarkLiveProfiles.resolve([danbooruConfig]),
  throwsA(isA<BookmarkLiveProfileException>()),
);
expect(
  () => BookmarkLiveProfiles.resolve([
    danbooruConfig,
    gelbooruV2Config,
    secondGelbooruV2Config,
  ]),
  throwsA(isA<BookmarkLiveProfileException>()),
);
```

Cover zero, duplicate, wrong-engine, and extra unrelated profiles. Unrelated profiles may exist; duplicates of either required engine are rejected.

- [ ] **Step 2: Write failing deterministic collector tests**

Inject paged candidate results and assert:

```dart
expect(manifest.entries, hasLength(1000));
expect(manifest.entries.first.profile, BenchmarkProfile.danbooru);
expect(manifest.entries[1].profile, BenchmarkProfile.gelbooruV2);
expect(manifest.entries.map((entry) => entry.sequence), orderedEquals(List.generate(1000, (i) => i)));
expect(coverage.videoOrAnimated, greaterThanOrEqualTo(10));
expect(coverage.hasComment, greaterThanOrEqualTo(10));
expect(coverage.hasNotesOrTranslation, greaterThanOrEqualTo(10));
expect(coverage.hasRelationship, greaterThanOrEqualTo(10));
expect(coverage.hasSource, greaterThanOrEqualTo(50));
```

Also test filtering non-general, deleted/banned, missing-media, and duplicate posts; starting at page 20; stopping after 500 valid posts per engine; failure after page 200; and deterministic output from identical candidate pages.

- [ ] **Step 3: Run both focused files and verify red**

Run:

```bash
fvm flutter test --no-pub test/core/developer_options/bookmark_live_benchmark/runtime_test.dart test/core/developer_options/bookmark_live_benchmark/collector_test.dart
```

Expected: compilation fails because runtime and collector types are undefined.

- [ ] **Step 4: Implement profile resolution and the feature post loader**

Use:

```dart
final class BookmarkLiveProfiles extends Equatable {
  const BookmarkLiveProfiles({
    required this.danbooru,
    required this.gelbooruV2,
  });

  factory BookmarkLiveProfiles.resolve(List<BooruConfig> configs) {
    final danbooru = configs.where((c) => c.auth.booruType == BooruType.danbooru).toList();
    final gelbooru = configs.where((c) => c.auth.booruType == BooruType.gelbooruV2).toList();
    if (danbooru.length != 1 || gelbooru.length != 1) {
      throw BookmarkLiveProfileException(
        danbooruCount: danbooru.length,
        gelbooruV2Count: gelbooru.length,
      );
    }
    return BookmarkLiveProfiles(danbooru: danbooru.single, gelbooruV2: gelbooru.single);
  }

  BooruConfig forProfile(BenchmarkProfile profile) => switch (profile) {
    BenchmarkProfile.danbooru => danbooru,
    BenchmarkProfile.gelbooruV2 => gelbooruV2,
  };
}
```

The feature `BookmarkLivePostLoaderAdapter` resolves the config. Its single-post method calls:

```dart
final result = await ref
    .read(originAwarePostRepoProvider(config))
    .getPost(NumericPostId(entry.postId), options: PostFetchOptions.raw)
    .run();
return result.fold((error) => throw BookmarkLiveFetchException(entry, error), (post) => post);
```

Its candidate-page method calls:

```dart
final result = await ref
    .read(originAwarePostRepoProvider(profiles.forProfile(profile)))
    .getPosts('', page, limit: limit, options: PostFetchOptions.raw)
    .run();
return result.fold(
  (error) => throw BookmarkLivePageFetchException(profile, page, error),
  (result) => result.posts,
);
```

- [ ] **Step 5: Implement deterministic live collection**

`BookmarkLiveManifestCollector` starts at page 20 and requests pages of 100 through page 200 using `PostFetchOptions.raw`. It retains only posts satisfying:

```dart
post.id > 0 &&
post.rating == Rating.general &&
!(post.status?.matches('deleted') ?? false) &&
!(post.status?.matches('banned') ?? false) &&
post.thumbnailImageUrl.isNotEmpty &&
post.originalImageUrl.isNotEmpty
```

Deduplicate by `(profile, post.id)`. Select coverage candidates first in this order: video/animated, comment, notes/translation, relationship, source, uploader; then fill remaining slots in encounter order. Alternate the two 500-entry lists into contiguous sequences `0..999`. Fail if any agreed coverage minimum from Step 2 is unmet.

Write `toCanonicalJson()` to:

```dart
final directory = await getExternalStorageDirectory();
final file = File('${directory!.path}/bookmark_live_manifest.json');
await file.writeAsString(manifest.toCanonicalJson(), flush: true);
```

The page displays only the path, count, digest, and non-sensitive progress.

- [ ] **Step 6: Wire normal bookmark storage into the coordinator**

The page obtains:

```dart
final repository = await ref.read(bookmarkRepoProvider.future);
final profiles = BookmarkLiveProfiles.resolve(ref.read(booruConfigProvider));
```

For each entry, resolve its config and write through:

```dart
await repository.addBookmark(
  config.booruIdHint,
  post,
  imageUrlResolver: (booruId) => ref.read(bookmarkUrlResolverProvider(booruId)),
  postLinkGenerator: (_) => ref.read(postLinkGeneratorProvider(config.auth)),
);
```

Use these exact closures for verification and rollback:

```dart
readBookmarks: () => repository.getAllBookmarksOrThrow(
  imageUrlResolver: (booruId) => ref.read(bookmarkUrlResolverProvider(booruId)),
),
removeBookmarks: repository.removeBookmarks,
```

Do not call a server favorite API.

- [ ] **Step 7: Add the temporary Dev-only UI entry without hardcoded copy**

Add getters to `DeveloperOptionsL10n` for the benchmark title, collect, validate, import, progress, success, and failure labels. Add a plain `ListTile` in `DeveloperOptionsPage`, matching the existing page style, that pushes `BookmarkLiveBenchmarkPage`. The page is reachable only because Developer Options itself is gated by `isDevEnvironmentProvider`.

The page has exactly three actions:

1. `Collect manifest` — generate and export candidates;
2. `Validate manifest` — parse the bundled/frozen manifest and live-fetch all entries without writing;
3. `Import bookmarks` — require successful validation, import, reload, and show exact count/digest.

Disable actions while work is active and show the logical profile/ID on failure, never URLs, credentials, or media.

- [ ] **Step 8: Format and run focused plus related tests**

Run:

```bash
fvm dart format lib/core/developer_options/bookmark_live_benchmark lib/core/developer_options/widgets.dart lib/core/developer_options/l10n.dart test/core/developer_options/bookmark_live_benchmark
fvm flutter test --no-pub test/core/developer_options/bookmark_live_benchmark test/core/bookmarks/bookmark_provider_test.dart
fvm flutter analyze --no-pub lib/core/developer_options/bookmark_live_benchmark lib/core/developer_options/widgets.dart lib/core/developer_options/l10n.dart test/core/developer_options/bookmark_live_benchmark
```

Expected: all focused/related tests pass and analysis reports no issues.

- [ ] **Step 9: Commit the feature harness runtime**

Run in `bookmark-live-feature`:

```bash
git add lib/core/developer_options/bookmark_live_benchmark lib/core/developer_options/widgets.dart lib/core/developer_options/l10n.dart test/core/developer_options/bookmark_live_benchmark
git diff --cached --check
git commit -m "test(bookmarks): add temporary live harness"
```

### Task 5: Collect, freeze, validate, and retain the 1,000-post manifest

**Files:**
- Create retained: `docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-manifest.json`
- Modify temporary: `pubspec.yaml`
- Modify progress: `docs/work/in-progress/QA-002-bookmark-live-comparison.md`

**Interfaces:**
- Consumes: live collector and page from Task 4, normal configured profiles, and the assigned emulator.
- Produces: one canonical 500/500 manifest and SHA-256 used unchanged by both revisions.

- [ ] **Step 1: Clear app data and build/install the feature harness in profile mode**

Run:

```bash
adb -s emulator-5556 shell am force-stop com.timberpile.boorusama.dev
adb -s emulator-5556 shell pm clear com.timberpile.boorusama.dev
fvm flutter run --profile --flavor dev -d emulator-5556 --dart-define=BOOKMARK_LIVE_BENCHMARK=true
```

Expected: the Dev app starts with empty app state. Keep this Flutter session attached while collecting.

- [ ] **Step 2: Create the two profiles without credential disclosure**

Read the two records in `/home/timber/code/Boorusama/.test_credentials` whose URL hosts identify Danbooru and Gelbooru. Through the normal UI, create exactly:

- one `BooruType.danbooru` profile for the Danbooru test record;
- one `BooruType.gelbooruV2` profile for the Gelbooru test record.

Enter values manually or through a local non-echoing helper. Do not place literal values in Maestro YAML or shell command text. Do not capture screens until both profile forms are closed. Confirm Developer Options reports one match for each required engine.

- [ ] **Step 3: Collect candidates and export the manifest**

Open Developer Options → Bookmark live comparison → Collect manifest. Wait for exactly 1,000 entries, 500/500 distribution, all coverage minimums, and a displayed digest.

Pull the non-sensitive exported file:

```bash
adb -s emulator-5556 pull /storage/emulated/0/Android/data/com.timberpile.boorusama.dev/files/bookmark_live_manifest.json /tmp/bookmark_live_manifest.json
sha256sum /tmp/bookmark_live_manifest.json
```

Expected: pull succeeds and the digest matches the app display.

- [ ] **Step 4: Add the canonical manifest to the feature branch**

Copy the generated file into both the original feature worktree and the temporary feature harness:

```bash
mkdir -p docs/superpowers/benchmarks
cp /tmp/bookmark_live_manifest.json docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-manifest.json
mkdir -p /home/timber/code/Boorusama/.worktrees/bookmark-live-feature/docs/superpowers/benchmarks
cp /tmp/bookmark_live_manifest.json /home/timber/code/Boorusama/.worktrees/bookmark-live-feature/docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-manifest.json
```

In `bookmark-live-feature`, add a parser test that loads the copied file with `File.readAsStringSync` and asserts count, distribution, alternation, and digest. Then run there:

```bash
fvm flutter test --no-pub test/core/developer_options/bookmark_live_benchmark/manifest_test.dart
sha256sum docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-manifest.json
```

Expected: the test passes and both recorded digests match.

- [ ] **Step 5: Live-validate the frozen manifest before either comparison run**

Copy the retained manifest into `bookmark-live-feature`, declare it under `flutter.assets` in temporary `pubspec.yaml`, rebuild the profile app, and use `Validate manifest`. Expected: every requested post exists, every returned ID matches, distribution is 500/500, and no writes occur.

If validation fails, select replacements through the same collector criteria, regenerate the entire canonical file and digest, and repeat this step before proceeding. Never patch only one comparison branch.

- [ ] **Step 6: Commit the retained list, not temporary asset wiring**

Run in the original feature worktree:

```bash
git add docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-manifest.json docs/work/in-progress/QA-002-bookmark-live-comparison.md
git diff --cached --check
git commit -m "test(bookmarks): add live comparison manifest"
```

Expected: the commit contains the canonical manifest and its digest/progress record only. The temporary `pubspec.yaml` change remains solely on the harness branch.

### Task 6: Add measurement markers and port the identical harness to `develop`

**Files:**
- Create temporary: `lib/core/developer_options/bookmark_live_benchmark/metrics.dart`
- Create temporary: `test/core/developer_options/bookmark_live_benchmark/metrics_test.dart`
- Modify temporary: `lib/core/bookmarks/src/providers/bookmark_provider.dart`
- Modify temporary: `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart`
- Modify temporary: `pubspec.yaml`
- Port temporary harness files to: `/home/timber/code/Boorusama/.worktrees/bookmark-live-develop`
- Replace develop-only: `lib/core/developer_options/bookmark_live_benchmark/post_loader.dart`

**Interfaces:**
- Produces structured lines beginning `BOOKMARK_LIVE_METRIC ` followed by canonical JSON and a persistent run number.
- Consumes the exact retained manifest from Task 5 as an asset on both harness branches.
- Develop adapter consumes `postRepoProvider(config.search)`; every other harness interface remains byte-identical.

- [ ] **Step 1: Write failing run-state and metric tests**

Test the temporary run-state repository and canonical metric shape. Assert that:

```dart
await runs.arm();
expect(await runs.claimNext(), 0);
expect(await runs.claimNext(), 1);
expect(jsonDecode(encodeMetric(metric)), {
  'name': 'bookmark_load',
  'revision': 'feature',
  'run': 2,
  'elapsedUs': 10000,
  'count': 1000,
  'mediaBlocked': true,
});
```

Also test that unarmed state emits nothing, `arm()` resets the next run to zero, and credential-like keys (`login`, `apiKey`, `password`, `token`) cannot be represented by the closed metric type.

- [ ] **Step 2: Implement non-sensitive structured metrics**

Use:

```dart
const bookmarkLiveBenchmarkEnabled = bool.fromEnvironment(
  'BOOKMARK_LIVE_BENCHMARK',
);

void emitBookmarkLiveMetric(BookmarkLiveMetric metric) {
  if (!bookmarkLiveBenchmarkEnabled) return;
  debugPrint('BOOKMARK_LIVE_METRIC ${metric.toCanonicalJson()}');
}
```

The metric object accepts only the fixed fields `name`, `revision`, `run`, `elapsedUs`, `count`, `bytes`, `slowFrames`, `missedFrames`, and `mediaBlocked`. Do not accept arbitrary maps. Back `BookmarkLiveRunRepository` with a dedicated Hive box, open/claim the run before starting the bookmark-load stopwatch, and arm/reset it only after a successful import.

- [ ] **Step 3: Instrument repository load and first grid frame**

In `BookmarkLibraryNotifier.build`, claim the persistent run number before starting a `Stopwatch`, wrap only `(await _service).load(...)`, and emit `bookmark_load` with `state.items.length` and `mediaBlocked: !ref.read(automaticMediaLoadingEnabledProvider)`. Do not include app boot, profile opening, or media.

In `_BookmarkScrollViewState`, start a stopwatch in `initState`. When `controller.itemsNotifier` first reaches 1,000 items, schedule one post-frame callback and emit `first_grid_frame`; guard with a boolean so rebuilds never emit twice.

- [ ] **Step 4: Prove markers do not affect normal builds**

Run:

```bash
fvm flutter test --no-pub test/core/developer_options/bookmark_live_benchmark/metrics_test.dart test/core/bookmarks/bookmark_provider_test.dart
fvm flutter analyze --no-pub lib/core/developer_options/bookmark_live_benchmark/metrics.dart lib/core/bookmarks/src/providers/bookmark_provider.dart lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart
```

Expected: tests and analysis pass. Add a test that invokes a metric with the compile-time flag absent or an unarmed run repository and observes no sink call.

- [ ] **Step 5: Commit the feature measurement harness**

Run in `bookmark-live-feature`:

```bash
git add lib/core/developer_options/bookmark_live_benchmark/metrics.dart test/core/developer_options/bookmark_live_benchmark/metrics_test.dart lib/core/bookmarks/src/providers/bookmark_provider.dart lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart pubspec.yaml docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-manifest.json
git diff --cached --check
git commit -m "test(bookmarks): instrument live comparison"
```

- [ ] **Step 6: Port the harness to the develop comparison branch**

Copy the newly created harness directory, its tests, the manifest asset, Developer Options changes, l10n changes, and asset declaration from `bookmark-live-feature` to `bookmark-live-develop`. Keep the new harness files byte-identical except `post_loader.dart`. Apply only the small measurement-marker hunks to the existing develop versions of `bookmark_provider.dart` and `bookmark_scroll_view.dart`; never overwrite those develop product files with their feature-branch versions.

Implement the develop adapter with:

```dart
final result = await ref
    .read(postRepoProvider(config.search))
    .getPost(NumericPostId(entry.postId), options: PostFetchOptions.raw)
    .run();
return result.fold((error) => throw BookmarkLiveFetchException(entry, error), (post) => post);
```

Implement its page method with the same `getPosts('', page, limit: limit, options: PostFetchOptions.raw)` call on `postRepoProvider(config.search)` and return `PostResult.posts` through `BookmarkLivePageFetchException` on failure.

Run:

```bash
fvm dart format lib/core/developer_options/bookmark_live_benchmark lib/core/developer_options/widgets.dart lib/core/developer_options/l10n.dart lib/core/bookmarks/src/providers/bookmark_provider.dart lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart test/core/developer_options/bookmark_live_benchmark
fvm flutter test --no-pub test/core/developer_options/bookmark_live_benchmark test/core/bookmarks/bookmark_provider_test.dart
fvm flutter analyze --no-pub lib/core/developer_options/bookmark_live_benchmark lib/core/developer_options/widgets.dart lib/core/bookmarks/src/providers/bookmark_provider.dart lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart
```

Expected: all harness and related tests pass on `develop`.

- [ ] **Step 7: Prove harness parity and commit develop instrumentation**

Compare file hashes for every temporary harness file except `post_loader.dart`:

```bash
diff -qr /home/timber/code/Boorusama/.worktrees/bookmark-live-feature/lib/core/developer_options/bookmark_live_benchmark /home/timber/code/Boorusama/.worktrees/bookmark-live-develop/lib/core/developer_options/bookmark_live_benchmark
sha256sum /home/timber/code/Boorusama/.worktrees/bookmark-live-feature/docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-manifest.json /home/timber/code/Boorusama/.worktrees/bookmark-live-develop/docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-manifest.json
```

Expected: `diff` reports only `post_loader.dart`; manifest hashes are identical.

Commit on `bookmark-live-develop`:

```bash
git add lib/core/developer_options/bookmark_live_benchmark lib/core/developer_options/widgets.dart lib/core/developer_options/l10n.dart lib/core/bookmarks/src/providers/bookmark_provider.dart lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart test/core/developer_options/bookmark_live_benchmark pubspec.yaml docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-manifest.json
git diff --cached --check
git commit -m "test(bookmarks): add temporary live harness"
```

### Task 7: Execute the sequential comparison and functional protocol

**Files:**
- Create temporary raw evidence: `/tmp/bookmark-live-comparison/develop/`
- Create temporary raw evidence: `/tmp/bookmark-live-comparison/feature/`
- Create retained: `docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-report.md`
- Update: `docs/work/in-progress/QA-002-bookmark-live-comparison.md`

**Interfaces:**
- Consumes: both committed harness branches and the frozen manifest.
- Produces: raw logs outside Git and one concise retained comparison report.

- [ ] **Step 1: Create the raw-evidence directories and record hashes**

Run:

```bash
mkdir -p /tmp/bookmark-live-comparison/develop /tmp/bookmark-live-comparison/feature
git -C /home/timber/code/Boorusama/.worktrees/bookmark-live-develop rev-parse HEAD
git -C /home/timber/code/Boorusama/.worktrees/bookmark-live-feature rev-parse HEAD
sha256sum docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-manifest.json
```

Expected: record all three hashes in the report before measurements.

- [ ] **Step 2: Run the complete setup for `develop`**

Build/install from `bookmark-live-develop`, clear app data first, recreate the two profiles from `.test_credentials`, validate the bundled manifest, import exactly 1,000 bookmarks, and verify 500/500 distribution. Use:

```bash
adb -s emulator-5556 shell am force-stop com.timberpile.boorusama.dev
adb -s emulator-5556 shell pm clear com.timberpile.boorusama.dev
fvm flutter run --profile --flavor dev -d emulator-5556 --dart-define=BOOKMARK_LIVE_BENCHMARK=true --dart-define=BOOKMARK_LIVE_REVISION=develop
```

Expected: importer success with exact manifest digest. Import duration is recorded only as setup context and excluded from all result tables.

- [ ] **Step 3: Capture one warm-up and four measured develop cold starts**

For each run, force-stop and relaunch without clearing data. Clear logcat before launch, open Bookmarks → All, wait for the 1,000 counter and the `first_grid_frame` marker, then dump logs:

```bash
adb -s emulator-5556 logcat -c
adb -s emulator-5556 shell am force-stop com.timberpile.boorusama.dev
adb -s emulator-5556 shell monkey -p com.timberpile.boorusama.dev -c android.intent.category.LAUNCHER 1
adb -s emulator-5556 logcat -d -v epoch | rg 'BOOKMARK_LIVE_METRIC'
adb -s emulator-5556 shell dumpsys meminfo com.timberpile.boorusama.dev
```

Before the warm-up, enable `Block automatic media loading` in Developer Options. Save run 0 separately as warm-up and save runs 1–4 as `cold-1.txt` through `cold-4.txt`. Reject any cold-run marker that does not contain `mediaBlocked: true`.

For every navigation or assertion in this step, use Maestro against `device_id: emulator-5556` explicitly. After each relaunch, inspect the current screen, navigate through the app menu to `Bookmarks`, open `All`, and assert that the 1,000-item state is visible before accepting the marker. Never rely on a successful ADB launch as proof that the app reached the target UI.

- [ ] **Step 4: Warm media and capture develop frame behavior**

Disable `Block automatic media loading`, perform one unmeasured pass over the fixed UI sequence to populate required thumbnails, and confirm no blocked-media placeholders remain in that sequence. Then reset frame stats, execute the same sequence, and dump stats:

```bash
adb -s emulator-5556 shell dumpsys gfxinfo com.timberpile.boorusama.dev reset
adb -s emulator-5556 shell dumpsys gfxinfo com.timberpile.boorusama.dev framestats
```

The fixed sequence is: open All, five upward swipes of identical duration, two downward swipes, open manifest sequence 0, swipe across sequences 0–9, open/close Danbooru details, swipe to Gelbooru V2, open/close details, and return to the grid. Inspect after each navigation boundary; command success alone is not product success.

- [ ] **Step 5: Run develop functional checks after measurement**

Record observed baseline behavior for profile markers, native/generic toolbars, mixed swipes, details/back navigation, black media, assertions, and fallback warnings. Remove sequence 0 locally, verify the current viewer response, exit, confirm count 999 and identity absence, restart, and confirm persistence/distribution. Do not press server favorite/vote controls.

- [ ] **Step 6: Record develop Hive storage size**

Run:

```bash
adb -s emulator-5556 shell run-as com.timberpile.boorusama.dev sh -c 'find . -type f -name "favorites*" -exec wc -c {} \;'
```

Expected: record every matching file and sum its byte counts in the report. If multiple files represent data and lock/journal state, list them separately.

- [ ] **Step 7: Repeat Steps 2–6 from cleared data for the feature harness**

Use `bookmark-live-feature` and:

```bash
fvm flutter run --profile --flavor dev -d emulator-5556 --dart-define=BOOKMARK_LIVE_BENCHMARK=true --dart-define=BOOKMARK_LIVE_REVISION=feature
```

The manifest, profile hosts, emulator, interaction sequence, cache-warm procedure, run count, and commands remain identical. Save raw evidence under `/tmp/bookmark-live-comparison/feature/`.

- [ ] **Step 8: Apply correctness and investigation rules**

Feature correctness fails on any crash, assertion, black media, wrong profile marker, wrong count/order, lost origin, stale native presentation, or generic fallback for a valid profile. Flag, but do not automatically fail, performance when:

```text
feature median load >= develop median load * 1.25
AND feature median load - develop median load >= 100 ms

feature settled PSS >= develop settled PSS * 1.25
AND feature settled PSS - develop settled PSS >= 50 MiB
```

Report repeated frames over 32 ms and high run variance. Treat Hive size as intentional-context data rather than an equality gate.

- [ ] **Step 9: Write the retained report**

Create the report with these exact sections:

```markdown
# Bookmark Live Comparison Report

## Revisions and environment
## Manifest identity and validation
## Setup exclusions
## Raw cold-load runs
## Median comparison
## Memory and Hive size
## Frame behavior
## Functional baseline on develop
## Feature-branch correctness
## Confounders and reruns
## Conclusion
```

Include raw numeric values and units, not screenshots of terminal output. Include no credentials, post media, or profile secrets. Clearly distinguish measurements from observations and unperformed checks.

- [ ] **Step 10: Reproduce any product defect once before fixing**

If a feature defect appears, repeat only its fixed functional sequence on the same feature harness without source edits. Classify it as application, backend, network, emulator, tooling, or inconclusive. Stop the comparison before changing code; fixes require a separate scoped task and fresh post-fix comparison.

### Task 8: Verify retained artifacts and hand off cleanup

**Files:**
- Verify: `docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-manifest.json`
- Verify: `docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-report.md`
- Move after verified acceptance: `docs/work/in-progress/QA-002-bookmark-live-comparison.md` → `docs/work/done/QA-002-bookmark-live-comparison.md`

**Interfaces:**
- Consumes: Task 7 report and raw evidence.
- Produces: reviewed durable evidence and an explicit cleanup decision; no product merge.

- [ ] **Step 1: Verify manifest and report hygiene**

Run:

```bash
sha256sum docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-manifest.json
rg -n "password|api[_-]?key|token|passHash|login|username" docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-manifest.json docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-report.md
git diff --check
```

Expected: digest matches the report; the credential scan has no matches; whitespace check passes.

- [ ] **Step 2: Verify the feature branch remains free of harness code**

Run in the original feature worktree:

```bash
git status --short
git diff --name-only origin/develop...HEAD
```

Expected: inspect the complete output and confirm that no temporary `bookmark_live_benchmark` path and no benchmark-only `pubspec.yaml` asset declaration is present on the product feature branch. The retained manifest/report and existing product feature changes are allowed.

- [ ] **Step 3: Update completion evidence and move the queue task**

Record revision hashes, manifest digest, four raw runs per revision, medians, memory, Hive bytes, frame results, functional outcome, and report path. Move the stable task filename to `docs/work/done/` only when every acceptance criterion is evidenced.

- [ ] **Step 4: Commit retained evidence**

Run:

```bash
git add docs/superpowers/benchmarks/2026-09-24-bookmark-live-comparison-report.md docs/work/done/QA-002-bookmark-live-comparison.md
git diff --cached --check
git commit -m "docs(bookmarks): report live comparison"
```

Expected: the commit contains the report and completed task evidence only.

- [ ] **Step 5: Present cleanup targets and wait for explicit approval**

Report the two worktrees, two local harness branches, their harness-only commits, and `/tmp/bookmark-live-comparison`. Do not remove or delete them in this step. After explicit approval, remove the two worktrees normally, prune worktree registrations, delete the two local harness branches, and remove the temporary raw directory. Never use forced worktree removal while uncommitted evidence remains.
