import 'package:booru_clients/e621.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

E621Client clientFor(Object? body) => E621Client(
  baseUrl: 'https://e926.net',
  dio: Dio(BaseOptions(baseUrl: 'https://e926.net'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path != '/favorites.json') {
            expect(options.queryParameters, containsPair('v2', 'true'));
            expect(options.queryParameters, containsPair('mode', 'extended'));
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: body,
            ),
          );
        },
      ),
    ),
);

void main() {
  test('reads original media and stats from extended responses', () async {
    final posts = await clientFor({
      'posts': [
        {
          'id': 15,
          'files': {
            'original': {'url': 'https://example.org/15.jpg', 'width': 700},
            'meta': {'ext': 'jpg', 'size': 145, 'duration': 2},
            'preview': {'webp': 'https://example.org/15.webp'},
          },
          'stats': {'fav_count': 3},
        },
      ],
    }).getPosts();
    expect(posts.single.file?.width, 700);
    expect(posts.single.preview?.alt, endsWith('.webp'));
    expect(posts.single.favCount, 3);
    expect(posts.single.duration, 2.0);
  });
  test(
    'single and popular posts keep video alternatives without a still sample',
    () async {
      final row = {
        'id': 3,
        'files': {
          'video': {
            'original': {'url': 'https://media.test/video.mp4'},
          },
        },
      };
      for (final post in [
        await clientFor({'post': row}).getPost(3),
        await clientFor(row).getPost(3),
        ...(await clientFor({
          'posts': [row],
        }).getPopularPosts(
          date: DateTime.utc(2026),
          scale: TimeScale.values.first,
        )),
      ]) {
        expect(post?.sample?.alternates?.original?.url, endsWith('.mp4'));
        expect(post?.sample?.url, isNull);
        expect(post?.file?.url, isNull);
      }
    },
  );
  for (final body in [
    null,
    <String, Object>{},
    {'success': false, 'message': 'Temporary restriction'},
    {'posts': null},
    {'success': false, 'posts': <Object>[]},
  ]) {
    test(
      'invalid successful HTTP payload cannot become history exhaustion: $body',
      () async {
        await expectLater(clientFor(body).getPosts(), throwsFormatException);
      },
    );
  }
  for (final body in [
    <Object>[],
    {'posts': <Object>[]},
  ]) {
    test('valid empty source response remains empty: $body', () async {
      expect(await clientFor(body).getPosts(), isEmpty);
    });
  }
}
