import 'dart:typed_data';

import 'package:booru_clients/core.dart';
import 'package:booru_clients/gelbooru.dart';
import 'package:booru_clients/src/gelbooru_v2/parsers/r34_parsers.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  test(
    'bodyless chunked JSON listing is an empty result through Dio',
    () async {
      final dio = Dio()..httpClientAdapter = _BodylessJsonAdapter();
      addTearDown(() => dio.close(force: true));
      final base = GelbooruV2Client.defaultEndpoints();
      final client = GelbooruV2Client(
        baseUrl: 'https://rule34.example/',
        dio: dio,
        config: base.withOverrides({
          BooruFeatureId.posts: base
              .getEndpoint(BooruFeatureId.posts)!
              .copyWith(
                parser: parseR34PostsApi,
              ),
        }),
      );

      final result = await client.getPosts(limit: 2, tags: ['no-such-tag']);

      expect(result.posts, isEmpty);
      expect(result.count, isNull);
    },
  );

  test('empty detail response still fails rather than losing a post', () {
    expect(
      () => parseR34PostApi(
        Response<Object?>(
          requestOptions: RequestOptions(),
          data: null,
          statusCode: 200,
        ),
        {P.postId: 42},
      ),
      throwsFormatException,
    );
  });
}

class _BodylessJsonAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '',
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
      'transfer-encoding': ['chunked'],
    },
  );

  @override
  void close({bool force = false}) {}
}
