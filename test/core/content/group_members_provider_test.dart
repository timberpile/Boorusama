import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/content/providers.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../search/following_topics/topic_test_utils.dart';

import 'package:boorusama/core/posts/post/types.dart';

void main() {
  late _Source source;
  late ProviderContainer container;
  late GroupLoadKey key;
  final group = const ContentReferenceCodec().parse(
    engine: BooruType.danbooru,
    site: Uri.parse('https://example.test'),
    kind: ContentKind.group,
    sourceKey: 'pool:42',
  );
  ContentReference post(int id) => const ContentReferenceCodec().parse(
    engine: group.engine,
    site: group.site,
    kind: ContentKind.post,
    sourceKey: 'id:$id',
  );
  GroupMember member(int id, String slot, int position) => GroupMember(
    reference: post(id),
    memberKey: slot,
    sourcePosition: position,
  );
  GroupMemberBatch batch(
    List<GroupMember> members, {
    String? next,
    int? total,
  }) => (
    page: ContentPage(
      items: members,
      next: next == null ? null : ContentCursor(next),
      total: total,
    ),
    resolved: <ContentEntry>[],
  );
  setUp(() {
    source = _Source();
    key = GroupLoadKey(reference: group, access: source.access.key);
    container = ProviderContainer(
      overrides: [
        contentGroupSourceProvider.overrideWith((ref, access) {
          ref.onDispose(source.dispose);
          return source;
        }),
      ],
    );
  });
  tearDown(() => container.dispose());
  void listen(GroupLoadKey value) {
    final subscription = container.listen(
      groupMembersProvider(value),
      (_, _) {},
    );
    addTearDown(subscription.close);
  }

  for (final hydration in ['first', 'none', 'last']) {
    test(
      'incompatible unhydrated identity across pages is rejected ($hydration)',
      () async {
        listen(key);
        final initial = container.read(groupMembersProvider(key).future);
        await source.requested(0);
        final incompatible = const ContentReferenceCodec().parse(
          engine: BooruType.e621,
          site: group.site,
          kind: ContentKind.post,
          sourceKey: 'id:7',
        );
        final realPost = testSearchPost(7, null).copyWith(
          origin: PostOrigin.fromSource(
            booruType: group.engine,
            booruId: 1,
            source: group.site.toString(),
          ),
        );
        final firstReference = hydration == 'last' ? incompatible : post(7);
        source.complete(0, (
          page: ContentPage(
            items: [
              GroupMember(
                reference: firstReference,
                memberKey: 'first',
                sourcePosition: 0,
              ),
            ],
            next: ContentCursor('next'),
          ),
          resolved: hydration == 'first'
              ? [PostContentEntry(reference: post(7), post: realPost)]
              : <ContentEntry>[],
        ));
        final before = await initial;
        final controller = container.read(groupMembersProvider(key).notifier);
        final next = controller.loadNext();
        await source.requested(1);
        source.complete(1, (
          page: ContentPage(
            items: [
              GroupMember(
                reference: hydration == 'last' ? post(7) : incompatible,
                memberKey: 'second',
                sourcePosition: 1,
              ),
            ],
          ),
          resolved: hydration == 'last'
              ? [PostContentEntry(reference: post(7), post: realPost)]
              : <ContentEntry>[],
        ));
        await next;
        final rejected = container.read(groupMembersProvider(key)).requireValue;
        expect(rejected.nextPageError, isNotNull);
        expect(rejected.members, before.members);
        expect(rejected.resolved, before.resolved);
        expect(rejected.next, before.next);
        final retry = controller.retryNext();
        await source.requested(2);
        expect(source.queries[2].cursor, before.next);
        source.complete(
          2,
          batch([
            GroupMember(
              reference: firstReference,
              memberKey: 'second',
              sourcePosition: 1,
            ),
          ]),
        );
        await retry;
        final accepted = container.read(groupMembersProvider(key)).requireValue;
        expect(accepted.members.map((m) => m.memberKey), ['first', 'second']);
        expect(accepted.nextPageError, isNull);
        expect(accepted.resolved, before.resolved);
      },
    );
  }

  for (final change in ['account', 'removal', 'policy', 'loading', 'error']) {
    test(
      '$change revocation erases already published members and metadata',
      () async {
        container.dispose();
        final sources = <ContentAccessKey, _Source>{};
        final visibility = StateProvider<AsyncValue<String>>(
          (ref) => const AsyncData('one'),
        );
        container = ProviderContainer(
          overrides: [
            booruConfigProvider.overrideWith(_Configs.new),
            contentEffectivePolicyProvider.overrideWith(
              (ref, id) => ref.watch(visibility),
            ),
            contentGroupSourceProvider.overrideWith((ref, access) {
              final context = ref.watch(contentAccessContextProvider(access));
              if (context == null) {
                throw AppError(
                  type: AppErrorType.loadDataFromServerFailed,
                  message: 'Scope revoked',
                );
              }
              return sources.putIfAbsent(
                access,
                () => _Source(context: context),
              );
            }),
          ],
        );
        final request = ContentAccessRequest(reference: group);
        final access = container.read(
          contentAccessForReferenceProvider(request),
        )!;
        final oldKey = GroupLoadKey(reference: group, access: access.key);
        listen(oldKey);
        final summaries = container.listen(
          groupSummaryProvider(oldKey.metadata),
          (_, _) {},
        );
        final details = container.listen(
          groupDetailsProvider(oldKey.metadata),
          (_, _) {},
        );
        addTearDown(summaries.close);
        addTearDown(details.close);
        final initial = container.read(groupMembersProvider(oldKey).future);
        final oldSource = sources[access.key]!;
        await oldSource.requested(0);
        final realPost = testSearchPost(7, null).copyWith(
          origin: PostOrigin.fromSource(
            booruType: group.engine,
            booruId: 1,
            source: group.site.toString(),
          ),
        );
        oldSource.complete(0, (
          page: ContentPage(
            items: [member(7, 'private', 0)],
            next: ContentCursor('next'),
          ),
          resolved: [PostContentEntry(reference: post(7), post: realPost)],
        ));
        expect((await initial).resolved, hasLength(1));
        await container.read(groupSummaryProvider(oldKey.metadata).future);
        await container.read(groupDetailsProvider(oldKey.metadata).future);
        final calls = (
          oldSource.queries.length,
          oldSource.summaryCalls,
          oldSource.detailsCalls,
        );
        switch (change) {
          case 'account':
            (container.read(booruConfigProvider.notifier) as _Configs)
                .replaceAccount();
          case 'removal':
            (container.read(booruConfigProvider.notifier) as _Configs).remove();
          case 'policy':
            container.read(visibility.notifier).state = const AsyncData('two');
          case 'loading':
            container.read(visibility.notifier).state = const AsyncLoading();
          case 'error':
            container.read(visibility.notifier).state = AsyncError(
              Exception('Fixture policy'),
              StackTrace.current,
            );
        }
        await container.pump();
        final revoked = container.read(groupMembersProvider(oldKey));
        expect(revoked.hasError, isTrue);
        expect(revoked.hasValue, isFalse);
        expect(revoked.valueOrNull, isNull);
        for (final metadata in [
          container.read(groupSummaryProvider(oldKey.metadata)),
          container.read(groupDetailsProvider(oldKey.metadata)),
        ]) {
          expect(metadata.hasError, isTrue);
          expect(metadata.hasValue, isFalse);
          expect(metadata.valueOrNull, isNull);
        }
        final oldController = container.read(
          groupMembersProvider(oldKey).notifier,
        );
        await oldController.loadNext();
        await oldController.refresh();
        expect((
          oldSource.queries.length,
          oldSource.summaryCalls,
          oldSource.detailsCalls,
        ), calls);
        final newAccess = container.read(
          contentAccessForReferenceProvider(request),
        );
        if (newAccess != null) {
          expect(newAccess.key, isNot(access.key));
          final newKey = GroupLoadKey(reference: group, access: newAccess.key);
          listen(newKey);
          final fresh = container.read(groupMembersProvider(newKey).future);
          final newSource = sources[newAccess.key]!;
          await newSource.requested(0);
          expect(
            container.read(groupMembersProvider(newKey)).hasValue,
            isFalse,
          );
          newSource.complete(0, batch([]));
          expect((await fresh).resolved, isEmpty);
        }
      },
    );
  }

  test('pages preserve occurrence order, gaps and raw continuation; concurrent next joins', () async {
    listen(key);
    final initial = container.read(groupMembersProvider(key).future);
    await source.requested(0);
    source.complete(
      0,
      batch(
        [member(7, 'first', 0), member(8, 'missing', 2)],
        next: 'page:2',
        total: 3,
      ),
    );
    final first = await initial;
    expect(first.firstPageLoaded, isTrue);
    expect(first.sourceTotal, 3);
    final controller = container.read(groupMembersProvider(key).notifier);
    final a = controller.loadNext();
    final b = controller.loadNext();
    expect(a, same(b));
    await source.requested(1);
    expect(source.queries[1].cursor!.token, 'page:2');
    source.complete(1, batch([member(7, 'again', 3)], total: 3));
    await a;
    final result = container.read(groupMembersProvider(key)).requireValue;
    expect(result.members.map((m) => m.memberKey), [
      'first',
      'missing',
      'again',
    ]);
    expect(result.members.map((m) => m.sourcePosition), [0, 2, 3]);
    expect(result.next, isNull);
    expect(result.loadingMore, isFalse);
    expect(source.queries, hasLength(2));
    expect(
      source.contexts.every((c) => c.replaySafety == ApiReplaySafety.safeRead),
      isTrue,
    );
  });

  test('next-page failure keeps members and cursor, and retry clears only that error', () async {
    listen(key);
    final initial = container.read(groupMembersProvider(key).future);
    await source.requested(0);
    source.complete(0, batch([member(1, 'one', 0)], next: 'next'));
    await initial;
    final controller = container.read(groupMembersProvider(key).notifier);
    final next = controller.loadNext();
    await source.requested(1);
    final error = ServerError(
      httpStatusCode: 429,
      message: 'Fixture rate limit',
    );
    source.fail(1, error);
    await next;
    final failed = container.read(groupMembersProvider(key)).requireValue;
    expect(failed.members.single.memberKey, 'one');
    expect(failed.next!.token, 'next');
    expect(failed.nextPageError, same(error));
    final retry = controller.retryNext();
    await source.requested(2);
    expect(source.queries[2].cursor, source.queries[1].cursor);
    source.complete(2, batch([member(2, 'two', 1)]));
    await retry;
    final done = container.read(groupMembersProvider(key)).requireValue;
    expect(done.members, hasLength(2));
    expect(done.nextPageError, isNull);
  });

  test(
    'empty filtered pages retain progress and stalled cursors remain retryable',
    () async {
      listen(key);
      final initial = container.read(groupMembersProvider(key).future);
      await source.requested(0);
      source.complete(0, batch([], next: 'next', total: 100));
      await initial;
      expect(
        source.queries,
        hasLength(1),
        reason: 'No automatic unbounded continuation',
      );
      final controller = container.read(groupMembersProvider(key).notifier);
      final next = controller.loadNext();
      await source.requested(1);
      source.complete(1, batch([], next: 'next'));
      await next;
      final failed = container.read(groupMembersProvider(key)).requireValue;
      expect(failed.next!.token, 'next');
      expect(failed.nextPageError, isNotNull);
      expect(failed.sourceTotal, 100);
      final retry = controller.retryNext();
      await source.requested(2);
      source.complete(2, batch([], next: 'progress'));
      await retry;
      expect(
        container.read(groupMembersProvider(key)).requireValue.next!.token,
        'progress',
      );
    },
  );

  test(
    'refresh cancels admission and ignores an uncooperative late next page',
    () async {
      listen(key);
      final initial = container.read(groupMembersProvider(key).future);
      await source.requested(0);
      source.complete(0, batch([member(1, 'old', 0)], next: 'next'));
      await initial;
      final controller = container.read(groupMembersProvider(key).notifier);
      final old = controller.loadNext();
      await source.requested(1);
      final refreshed = controller.refresh();
      await source.requested(2);
      await source.contexts[1].cancelToken!.whenCancel;
      expect(source.contexts[1].cancelToken!.isCancelled, isTrue);
      source.complete(2, batch([member(3, 'fresh', 2)]));
      await refreshed;
      source.complete(1, batch([member(2, 'late', 1)]));
      await old;
      expect(
        container
            .read(groupMembersProvider(key))
            .requireValue
            .members
            .map((m) => m.memberKey),
        ['fresh'],
      );
      expect(source.invalidations, 1);
    },
  );

  test(
    'refresh during initial loading completes with only the new generation',
    () async {
      listen(key);
      final first = container.read(groupMembersProvider(key).future);
      await source.requested(0);
      final refreshed = container
          .read(groupMembersProvider(key).notifier)
          .refresh();
      await source.requested(1);
      await source.contexts[0].cancelToken!.whenCancel;
      source.complete(1, batch([member(2, 'fresh', 2)]));
      await refreshed;
      expect((await first).members.single.memberKey, 'fresh');
      source.complete(0, batch([member(1, 'stale', 0)]));
      await source.responses[0].future;
      expect(
        container
            .read(groupMembersProvider(key))
            .requireValue
            .members
            .single
            .memberKey,
        'fresh',
      );
    },
  );

  test(
    'rejected pages do not partially mutate member indexes or retry cursors',
    () async {
      listen(key);
      final initial = container.read(groupMembersProvider(key).future);
      await source.requested(0);
      source.complete(0, batch([member(1, 'one', 0)], next: 'next'));
      await initial;
      final controller = container.read(groupMembersProvider(key).notifier);
      final failed = controller.loadNext();
      await source.requested(1);
      source.complete(1, batch([member(2, 'two', 1), member(3, 'one', 2)]));
      await failed;
      expect(
        container
            .read(groupMembersProvider(key))
            .requireValue
            .members
            .single
            .memberKey,
        'one',
      );
      expect(
        container.read(groupMembersProvider(key)).requireValue.next!.token,
        'next',
      );
      final retry = controller.retryNext();
      await source.requested(2);
      source.complete(2, batch([member(2, 'two', 1)]));
      await retry;
      expect(
        container
            .read(groupMembersProvider(key))
            .requireValue
            .members
            .map((m) => m.memberKey),
        ['one', 'two'],
      );
    },
  );

  test('a newly unavailable occurrence loses hydrated metadata and keeps its source position', () async {
    listen(key);
    final initial = container.read(groupMembersProvider(key).future);
    await source.requested(0);
    final realPost = testSearchPost(7, null).copyWith(
      origin: PostOrigin.fromSource(
        booruType: group.engine,
        booruId: 1,
        source: group.site.toString(),
      ),
    );
    source.complete(0, (
      page: ContentPage(
        items: [
          GroupMember(
            reference: post(7),
            memberKey: 'slot',
            sourcePosition: 7,
            availability: MemberAvailability.available,
          ),
        ],
        next: ContentCursor('next'),
      ),
      resolved: [PostContentEntry(reference: post(7), post: realPost)],
    ));
    await initial;
    final next = container.read(groupMembersProvider(key).notifier).loadNext();
    await source.requested(1);
    source.complete(
      1,
      batch([
        GroupMember(
          reference: post(7),
          memberKey: 'slot',
          availability: MemberAvailability.unavailable,
        ),
      ]),
    );
    await next;
    final state = container.read(groupMembersProvider(key)).requireValue;
    expect(state.resolved, isEmpty);
    expect(state.members.single.sourcePosition, 7);
    expect(state.members.single.availability, MemberAvailability.unavailable);
  });

  test(
    'bulk caller admission, cancellation and retry policy are preserved',
    () async {
      listen(key);
      final initial = container.read(groupMembersProvider(key).future);
      await source.requested(0);
      source.complete(0, batch([member(1, 'first', 0)], next: 'next'));
      await initial;
      final controller = container.read(groupMembersProvider(key).notifier);
      final parent = CancelToken();
      final next = runWithApiRequestContext(
        ApiRequestContext(
          requestClass: ApiRequestClass.bulkTransfer,
          cancelToken: parent,
          allowCooldownRetry: false,
        ),
        controller.loadNext,
      );
      await source.requested(1);
      expect(source.contexts[1].requestClass, ApiRequestClass.bulkTransfer);
      expect(source.contexts[1].allowCooldownRetry, isFalse);
      parent.cancel('Bulk observer cancelled');
      await source.contexts[1].cancelToken!.whenCancel;
      await next;
      expect(
        container.read(groupMembersProvider(key)).requireValue.nextPageError,
        isA<RequestCancelledError>(),
      );
      final retry = controller.retryNext();
      await source.requested(2);
      source.complete(2, batch([member(2, 'retry', 1)]));
      await retry;
      source.complete(1, batch([member(3, 'cancelled', 2)]));
      await source.responses[1].future;
      expect(
        container
            .read(groupMembersProvider(key))
            .requireValue
            .members
            .map((m) => m.memberKey),
        ['first', 'retry'],
      );
    },
  );

  for (final change in ['account', 'policy']) {
    test(
      '$change revocation blocks late members and fails the old scope',
      () async {
        container.dispose();
        final sources = <ContentAccessKey, _Source>{};
        final visibility = StateProvider((ref) => 'policy:one');
        container = ProviderContainer(
          overrides: [
            booruConfigProvider.overrideWith(_Configs.new),
            contentEffectivePolicyProvider.overrideWith(
              (ref, id) => AsyncData(ref.watch(visibility)),
            ),
            contentGroupSourceProvider.overrideWith((ref, access) {
              final context = ref.watch(contentAccessContextProvider(access));
              if (context == null) {
                throw AppError(
                  type: AppErrorType.loadDataFromServerFailed,
                  message: 'Scope revoked',
                );
              }
              return sources.putIfAbsent(
                access,
                () => _Source(context: context),
              );
            }),
          ],
        );
        final request = ContentAccessRequest(reference: group);
        final beforeAccess = container.read(
          contentAccessForReferenceProvider(request),
        )!;
        final beforeKey = GroupLoadKey(
          reference: group,
          access: beforeAccess.key,
        );
        listen(beforeKey);
        final before = container.read(groupMembersProvider(beforeKey).future);
        final cancelled = expectLater(before, throwsA(isA<BooruError>()));
        final oldSource = sources[beforeAccess.key]!;
        await oldSource.requested(0);
        if (change == 'account') {
          (container.read(booruConfigProvider.notifier) as _Configs)
              .replaceAccount();
        } else {
          container.read(visibility.notifier).state = 'policy:two';
        }
        final afterAccess = container.read(
          contentAccessForReferenceProvider(request),
        )!;
        expect(afterAccess.key, isNot(beforeAccess.key));
        final afterKey = GroupLoadKey(
          reference: group,
          access: afterAccess.key,
        );
        listen(afterKey);
        final after = container.read(groupMembersProvider(afterKey).future);
        final newSource = sources[afterAccess.key]!;
        await newSource.requested(0);
        newSource.complete(0, batch([member(2, 'current', 2)]));
        expect((await after).members.single.memberKey, 'current');
        await container.pump();
        await oldSource.contexts[0].cancelToken!.whenCancel;
        expect(oldSource.contexts[0].cancelToken!.isCancelled, isTrue);
        oldSource.complete(0, batch([member(1, 'stale', 0)]));
        await cancelled;
        expect(
          container
              .read(groupMembersProvider(afterKey))
              .requireValue
              .members
              .single
              .memberKey,
          'current',
        );
        final oldState = container.read(groupMembersProvider(beforeKey));
        expect(oldState.hasError, isTrue);
        expect(oldState.valueOrNull?.members ?? [], isEmpty);
      },
    );
  }

  test(
    'initial failure uses AsyncError and disposal cancels pending work',
    () async {
      listen(key);
      final initial = container.read(groupMembersProvider(key).future);
      final failure = expectLater(initial, throwsA(isA<ServerError>()));
      await source.requested(0);
      source.fail(0, ServerError(httpStatusCode: 403, message: 'Unavailable'));
      await failure;
      expect(container.read(groupMembersProvider(key)).hasError, isTrue);
      final otherKey = GroupLoadKey(
        reference: group,
        access: source.access.key,
        orderKey: 'newest',
      );
      final subscription = container.listen(
        groupMembersProvider(otherKey),
        (_, _) {},
      );
      final pending = container.read(groupMembersProvider(otherKey).future);
      final cancelled = expectLater(
        pending,
        throwsA(isA<RequestCancelledError>()),
      );
      await source.requested(1);
      subscription.close();
      await container.pump();
      await source.contexts[1].cancelToken!.whenCancel;
      expect(source.contexts[1].cancelToken!.isCancelled, isTrue);
      source.complete(1, batch([member(1, 'late', 0)]));
      await cancelled;
    },
  );
}

class _Source extends ContentGroupSource {
  _Source({ContentAccessContext? context}) : access = context ?? _context();
  @override
  final ContentAccessContext access;
  final queries = <GroupMemberQuery>[];
  final contexts = <ApiRequestContext>[];
  final responses = <Completer<Either<BooruError, GroupMemberBatch>>>[];
  final signals = <int, Completer<void>>{};
  var invalidations = 0;
  var summaryCalls = 0;
  var detailsCalls = 0;
  Future<void> requested(int index) => queries.length > index
      ? Future.value()
      : signals.putIfAbsent(index, Completer<void>.new).future;
  void complete(int index, GroupMemberBatch value) =>
      responses[index].complete(Right(value));
  void fail(int index, BooruError error) =>
      responses[index].complete(Left(error));
  @override
  TaskEither<BooruError, GroupMemberBatch> loadMembers(
    GroupMemberQuery query,
  ) => TaskEither(() {
    final index = queries.length;
    queries.add(query);
    contexts.add(ApiRequestContext.current());
    final response = Completer<Either<BooruError, GroupMemberBatch>>();
    responses.add(response);
    signals[index]?.complete();
    return response.future;
  });
  @override
  TaskEither<BooruError, ContentGroupSummary> loadSummary(
    ContentReference reference,
  ) {
    summaryCalls++;
    return TaskEither.right(ContentGroupSummary(reference: reference));
  }

  @override
  TaskEither<BooruError, ContentGroupDetails> loadDetails(
    ContentReference reference,
  ) {
    detailsCalls++;
    return TaskEither.right(
      ContentGroupDetails(summary: ContentGroupSummary(reference: reference)),
    );
  }

  @override
  void invalidate(ContentReference reference) {
    invalidations++;
  }
}

ContentAccessContext _context() => ContentAccessContext.profile(
  config: BooruConfig.fromJson({
    ...BooruConfig.empty.toJson(),
    'id': '00000000-0000-4000-8000-000000000001',
    'booruId': 1,
    'booruIdHint': 1,
    'url': 'https://example.test',
  }),
  authEpoch: 1,
  policyEpoch: 1,
);

class _Configs extends BooruConfigNotifier {
  _Configs() : super(initialConfigs: [_context().config!]);
  void remove() => state = [];
  void replaceAccount() => state = [
    BooruConfig.fromJson({
      ...state.single.toJson(),
      'apiKey': 'replacement-fixture',
    }),
  ];
}
