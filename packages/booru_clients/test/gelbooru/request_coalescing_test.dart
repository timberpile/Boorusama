import 'dart:async';

import 'package:booru_clients/gelbooru.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  test(
    'a count probe cannot supply the result of a concurrent normal page',
    () async {
      final limits = <int>[];
      final firstStarted = Completer<void>();
      final release = Completer<void>();
      final dio = Dio(BaseOptions(baseUrl: 'https://gelbooru.example/'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) async {
              final limit = request.queryParameters['limit'] as int;
              limits.add(limit);
              if (!firstStarted.isCompleted) firstStarted.complete();
              await release.future;
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {
                    '@attributes': {'count': 100},
                    'post': [
                      for (var i = 0; i < limit; i++)
                        {'id': 100 - i, if (i == 0) 'md5': 'visible'},
                    ],
                  },
                ),
              );
            },
          ),
        );
      addTearDown(dio.close);
      final client = GelbooruClient(dio: dio);
      final probe = client.getPosts(page: 1, limit: 1);
      await firstStarted.future;
      final normal = client.getPosts(page: 1, limit: 3);
      final same = client.getPosts(page: 1, limit: 3);
      release.complete();
      expect((await probe).lastId, 100);
      final page = await normal;
      expect(page.posts, hasLength(1));
      expect(page.lastId, 98);
      expect((await same).rawIds, [100, 99, 98]);
      expect(limits, [1, 3]);
    },
  );
}
