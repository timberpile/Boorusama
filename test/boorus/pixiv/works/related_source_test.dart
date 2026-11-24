import 'dart:async';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/works/related_source.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'work_test_fixtures.dart';

void main() {
  test('revoking the profile cancels an in-flight preview request', () async {
    final access = workAccess();
    final current = StateProvider<ContentAccessContext?>((_) => access);
    final request = Completer<RequestOptions>();
    final reply = Completer<RequestInterceptorHandler>();
    final dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request.complete(options);
          reply.complete(handler);
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [
        contentAccessContextProvider.overrideWith(
          (ref, _) => ref.watch(current),
        ),
        contentEffectiveBlacklistProvider.overrideWith(
          (_, _) => const AsyncData(<String>{}),
        ),
        pixivClientProvider.overrideWith(
          (_, _) => PixivClient(accessToken: 'fixture', dio: dio),
        ),
      ],
    );
    addTearDown(container.dispose);
    final provider = pixivRelatedFirstPageProvider((
      access: access.key,
      illustId: 42,
    ));
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final pending = await request.future;

    container.read(current.notifier).state = null;
    await container.pump();
    expect(pending.cancelToken!.isCancelled, isTrue);
    (await reply.future).resolve(
      Response(
        requestOptions: pending,
        data: {
          'illusts': [
            {'id': 1},
          ],
        },
      ),
    );
    await container.pump();
    expect(container.read(provider).hasValue, isFalse);
    expect(container.read(provider).error, isA<StateError>());
  });

  test('filters the anchor, muted and hidden Works before deduplication', () {
    final access = workAccess();
    final page = filterPixivRelatedPage(
      PixivRelatedPage([
        work(id: 42),
        work(id: 1, visible: false),
        work(id: 2, muted: true),
        work(
          id: 3,
          tags: [
            {'name': 'blocked'},
          ],
        ),
        work(id: 4),
        work(id: 1),
        work(id: 4),
      ]),
      (access: access.key, illustId: 42),
      access,
      {'blocked'},
    );
    expect(page.illusts.map((dto) => dto.id), [4, 1]);
  });

  test('uses preview data, retries the same cursor, deduplicates and stops a cycle', () async {
    final cursor = await _cursor();
    var loads = 0;
    final session = PixivRelatedSession(
      firstPage: PixivRelatedPage([work(id: 1)], nextCursor: cursor),
      load: (next, _) async {
        loads++;
        if (next == null) return PixivRelatedPage([work(id: 2)]);
        expect(next, cursor);
        if (loads == 1) throw StateError('transient failure');
        return PixivRelatedPage(
          [work(id: 1), work(id: 3)],
          nextCursor: cursor,
        );
      },
    );

    expect((await session.fetch(1)).illusts.single.id, 1);
    expect(loads, 0);
    await expectLater(session.fetch(2), throwsStateError);
    final second = await session.fetch(2);
    expect(second.illusts.single.id, 3);
    expect(second.hasMore, isFalse);
    expect((await session.fetch(3)).illusts, isEmpty);
    expect(loads, 2);
    expect((await session.fetch(1)).illusts.single.id, 2);
    expect(loads, 3);
  });

  test('discarded continuations cannot advance the session', () async {
    final cursor = await _cursor();
    final token = CancelToken();
    var calls = 0;
    final session = PixivRelatedSession(
      firstPage: PixivRelatedPage([work(id: 1)], nextCursor: cursor),
      load: (next, _) async {
        expect(next, cursor);
        if (calls++ == 0) token.cancel();
        return PixivRelatedPage([work(id: 2)]);
      },
    );
    await session.fetch(1);
    await expectLater(
      runWithApiRequestContext(
        ApiRequestContext(cancelToken: token),
        () => session.fetch(2),
      ),
      throwsStateError,
    );
    expect((await session.fetch(2)).illusts.single.id, 2);
  });
}

Future<PixivRelatedCursor> _cursor() async {
  final dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response(
          requestOptions: options,
          data: {
            'illusts': [],
            'next_url':
                '$kPixivApiBaseUrl/v2/illust/related'
                '?illust_id=42&filter=for_ios&viewed[0]=1',
          },
        ),
      ),
    ),
  );
  final result = await PixivClient(
    accessToken: 'fixture',
    dio: dio,
  ).getRelatedIllusts(illustId: 42);
  return result.nextCursor!;
}
