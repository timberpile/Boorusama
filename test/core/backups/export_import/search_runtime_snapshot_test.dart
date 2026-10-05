import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/export_import/import/import_journal.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_transaction.dart';
import 'package:boorusama/core/backups/export_import/import/search_runtime_snapshot.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/foundation/filesystem.dart';

import '../../search/subscriptions/subscription_test_utils.dart';
import 'import_transaction_test_utils.dart';

void main() {
  late SearchSubscriptionRepository repository;
  late SearchRuntimeSnapshotService service;
  late SearchRuntimeSnapshot expected;

  setUp(() async {
    repository = memorySubscriptionRepository();
    service = SearchRuntimeSnapshotService(repository);
    final checkedAt = DateTime.utc(2026, 10, 2, 8);
    final independent = SearchSubscription(
      id: 'independent',
      profileId: '00000000-0000-4000-8000-000000000004',
      query: 'rating:safe cats',
      name: 'Cats',
      position: 0,
      createdAt: checkedAt.subtract(const Duration(days: 3)),
      previews: [
        SearchPostPreview(
          postId: 42,
          postCreatedAt: checkedAt.subtract(const Duration(hours: 1)),
          thumbnailUrl: 'https://example.com/42-thumb.jpg',
          sampleUrl: 'https://example.com/42.jpg',
          discoveredAt: checkedAt,
        ),
      ],
      recentPostIdentities: [
        RecentSearchPostIdentity(
          postId: 41,
          postCreatedAt: checkedAt.subtract(const Duration(hours: 2)),
        ),
      ],
      unreadCount: 1,
      lastAttemptAt: checkedAt,
      lastSuccessfulCheckAt: checkedAt.subtract(const Duration(minutes: 5)),
      highestSeenPostId: 42,
      lastErrorKind: SearchRefreshErrorKind.rateLimited,
      runtimeRevision: 7,
    );
    final feedSource = SearchSubscription(
      id: 'feed-source',
      profileId: '00000000-0000-4000-8000-000000000004',
      query: 'landscape',
      position: 0,
      createdAt: checkedAt.subtract(const Duration(days: 2)),
      previews: const [],
      recentPostIdentities: const [],
      unreadCount: 0,
      lastAttemptAt: checkedAt,
      lastSuccessfulCheckAt: checkedAt,
      highestSeenPostId: 100,
      runtimeRevision: 3,
    );
    await repository.restoreForProfile('00000000-0000-4000-8000-000000000004', [
      independent,
      feedSource,
    ]);
    await repository.restoreFeeds('00000000-0000-4000-8000-000000000004', [
      SearchFollowingFeed(
        id: 'feed',
        profileId: '00000000-0000-4000-8000-000000000004',
        name: 'Landscapes',
        sourceIds: const ['feed-source'],
        posts: [
          feedPostSnapshotFromPost(TestSearchPost(100, checkedAt)),
        ],
      ),
    ]);
    await repository.replaceOrganization(
      SearchOrganization(
        folders: [
          SharedSearchFolder(
            id: 'folder',
            name: 'Reference',
            searchIds: const ['independent'],
          ),
        ],
        homeSearchIds: const [],
      ),
    );
    expected = await service.capture();
  });

  test('round trips every search and feed runtime field', () {
    final decoded = const SearchRuntimeSnapshotCodec().decode(
      const SearchRuntimeSnapshotCodec().encode(expected),
    );

    expect(decoded, expected);
  });

  test('restores searches, feed caches, and organization exactly', () async {
    await service.restore(SearchRuntimeSnapshot.empty());

    await service.restore(expected);

    expect(await service.capture(), expected);
  });

  test('a later import failure restores all search runtime state', () async {
    final directory = await Directory.systemTemp.createTemp(
      'search_runtime_rollback_',
    );
    addTearDown(() => directory.delete(recursive: true));
    const fs = IoFileSystem();
    final store = ImportJournalStore(fs: fs, rootPath: directory.path);
    final runtime = _RuntimeImportSource(service: service, fs: fs);
    final failing = FakeImportSource('later', fs, failApply: true);

    await expectLater(
      ImportTransaction(store: store, fs: fs).execute(
        transactionId: 'runtime',
        plan: buildValidatedPlan(['pinned_searches', 'later']),
        sources: {'pinned_searches': runtime, 'later': failing},
      ),
      throwsStateError,
    );

    expect(await service.capture(), expected);
  });
}

final class _RuntimeImportSource implements ImportTransactionSource {
  const _RuntimeImportSource({required this.service, required this.fs});

  final SearchRuntimeSnapshotService service;
  final AppFileSystem fs;

  @override
  String get id => 'pinned_searches';

  @override
  Future<void> apply(ResolvedImportSource plan) =>
      service.restore(SearchRuntimeSnapshot.empty());

  @override
  Future<void> captureRollback(String outputPath) async {
    final snapshot = await service.capture();
    await fs.writeString(
      outputPath,
      const SearchRuntimeSnapshotCodec().encode(snapshot),
    );
  }

  @override
  Future<void> durableSync() async {}

  @override
  Future<String> revisionToken() async => 'revision';

  @override
  Future<void> restore(String rollbackPath) async {
    await service.restore(
      const SearchRuntimeSnapshotCodec().decode(
        await fs.readString(rollbackPath),
      ),
    );
  }
}
