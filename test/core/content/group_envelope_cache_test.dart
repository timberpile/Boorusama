import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/content/groups/group_envelope_cache.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final access = ContentAccessKey(
    engine: BooruType.danbooru,
    siteNamespace: 'example.test',
    profileId: '00000000-0000-4000-8000-000000000001',
    authEpoch: 1,
    policyEpoch: 1,
  );
  ContentReference reference(int id) => const ContentReferenceCodec().parse(
    engine: access.engine,
    site: Uri.parse('https://example.test'),
    kind: ContentKind.group,
    sourceKey: 'pool:$id',
  );

  test(
    'shared raw envelope survives cancellation of only one observer',
    () async {
      final cache = GroupEnvelopeCache<int>(access: access);
      addTearDown(cache.dispose);
      final response = Completer<int>();
      final firstToken = CancelToken();
      final secondToken = CancelToken();
      ApiRequestContext? rawContext;
      var calls = 0;
      Future<int> load() {
        calls++;
        rawContext = ApiRequestContext.current();
        return response.future;
      }

      final first = runWithApiRequestContext(
        ApiRequestContext(cancelToken: firstToken),
        () => cache.load(reference(42), load),
      );
      final firstCancelled = expectLater(
        first,
        throwsA(isA<RequestCancelledError>()),
      );
      final second = runWithApiRequestContext(
        ApiRequestContext(cancelToken: secondToken),
        () => cache.load(reference(42), load),
      );
      expect(calls, 1);
      firstToken.cancel('First observer left');
      await firstCancelled;
      expect(rawContext!.cancelToken!.isCancelled, isFalse);
      expect(rawContext!.canStart!(), isTrue);
      response.complete(7);
      expect(await second, 7);
      expect(await cache.load(reference(42), load), 7);
      expect(calls, 1);
    },
  );

  test('joining visible observers update the existing request priority and dispatch ownership', () async {
    final cache = GroupEnvelopeCache<int>(access: access);
    addTearDown(cache.dispose);
    final response = Completer<int>();
    final priorityChanged = Completer<void>();
    ApiRequestContext? raw;
    var dispatched = 0;
    void started() {
      dispatched++;
    }

    final background = runWithApiRequestContext(
      ApiRequestContext(
        requestClass: ApiRequestClass.bulkTransfer,
        allowCooldownRetry: false,
        onStarted: started,
      ),
      () => cache.load(reference(42), () {
        raw = ApiRequestContext.current();
        return response.future;
      }),
    );
    final subscription = raw!.changes!.listen((_) {
      if (raw!.requestClass == ApiRequestClass.interactive &&
          !priorityChanged.isCompleted) {
        priorityChanged.complete();
      }
    });
    addTearDown(subscription.cancel);
    final visible = runWithApiRequestContext(
      ApiRequestContext(onStarted: started),
      () => cache.load(
        reference(42),
        () => throw StateError('Redundant request'),
      ),
    );
    await priorityChanged.future;
    expect(raw!.allowCooldownRetry, isTrue);
    raw!.onStarted!();
    expect(dispatched, 1);
    response.complete(7);
    expect(await background, 7);
    expect(await visible, 7);
  });

  test(
    'last observer cancellation aborts admission and late data is not cached',
    () async {
      final cache = GroupEnvelopeCache<int>(access: access);
      addTearDown(cache.dispose);
      final response = Completer<int>();
      final token = CancelToken();
      ApiRequestContext? raw;
      final old = runWithApiRequestContext(
        ApiRequestContext(cancelToken: token),
        () => cache.load(reference(42), () {
          raw = ApiRequestContext.current();
          return response.future;
        }),
      );
      final cancelled = expectLater(old, throwsA(isA<RequestCancelledError>()));
      token.cancel('Route left');
      await cancelled;
      expect(raw!.cancelToken!.isCancelled, isTrue);
      expect(raw!.canStart!(), isFalse);
      response.complete(1);
      expect(await cache.load(reference(42), () async => 2), 2);
    },
  );

  test(
    'capacity, invalidation and account boundaries bound raw request reuse',
    () async {
      final cache = GroupEnvelopeCache<int>(access: access, maxEntries: 2);
      addTearDown(cache.dispose);
      var calls = 0;
      Future<int> load(int id) =>
          cache.load(reference(id), () async => ++calls);
      expect(await load(1), 1);
      expect(await load(2), 2);
      expect(await load(3), 3);
      expect(
        await load(1),
        4,
        reason: 'The oldest completed raw envelope was evicted',
      );
      cache.invalidate(reference(1));
      expect(await load(1), 5);
      final other = GroupEnvelopeCache<int>(
        access: ContentAccessKey(
          engine: access.engine,
          siteNamespace: access.siteNamespace,
          profileId: '00000000-0000-4000-8000-000000000002',
          authEpoch: 1,
          policyEpoch: 1,
        ),
      );
      addTearDown(other.dispose);
      expect(await other.load(reference(1), () async => ++calls), 6);
      final pending = Completer<int>();
      final bounded = GroupEnvelopeCache<int>(access: access, maxEntries: 1);
      addTearDown(bounded.dispose);
      final held = bounded.load(reference(1), () => pending.future);
      await expectLater(
        bounded.load(reference(2), () async => 2),
        throwsA(isA<ApiRequestDeferredException>()),
      );
      pending.complete(1);
      expect(await held, 1);
    },
  );

  test(
    'invalidated generation and foreign references never publish raw data',
    () async {
      final cache = GroupEnvelopeCache<int>(access: access);
      addTearDown(cache.dispose);
      final pending = Completer<int>();
      final first = cache.load(reference(42), () => pending.future);
      final cancelled = expectLater(
        first,
        throwsA(isA<RequestCancelledError>()),
      );
      cache.invalidate(reference(42));
      await cancelled;
      pending.complete(1);
      expect(await cache.load(reference(42), () async => 2), 2);
      final foreign = const ContentReferenceCodec().parse(
        engine: access.engine,
        site: Uri.parse('https://foreign.test'),
        kind: ContentKind.group,
        sourceKey: 'pool:42',
      );
      await expectLater(
        cache.load(foreign, () async => 3),
        throwsFormatException,
      );
    },
  );
}
