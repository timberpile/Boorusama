import 'dart:convert';

import 'package:booru_clients/generated.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/boorus/gelbooru_v2/client_provider.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2_provider.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/parser.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';

void main() {
  final config = BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: BooruType.gelbooruV2,
      url: 'https://rule34.xxx/',
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': '00000000-0000-4000-8000-000000000042',
    'login': 'synthetic-user-id',
    'apiKey': 'synthetic-api-key',
  });
  final post = <String, dynamic>{
    'id': 42,
    'file_url': 'https://images.example/abc.mp4',
    'sample_url': 'https://images.example/abc.jpg',
    'preview_url': 'https://images.example/thumbnail_abc.jpg',
    'hash': 'abc',
    'tags': 'portrait animated',
    'width': 1280,
    'height': 720,
    'score': 12,
    'parent_id': 7,
    'owner': 'synthetic-owner',
    'rating': 'e',
    'has_notes': true,
    'source': 'https://source.example/post/42',
  };

  late ProviderContainer container;
  late Object? responseData;
  late List<RequestOptions> requests;
  setUp(() {
    requests = [];
    responseData = [post];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                data: responseData,
                statusCode: 200,
              ),
            );
          },
        ),
      );
    container = ProviderContainer(
      overrides: [
        gelbooruV2Provider.overrideWithValue(
          GelbooruV2(
            config: BooruYamlConfigs.gelbooruV2,
            globalUserParams:
                BooruYamlConfigs.gelbooruV2.globalUserParams ?? {},
          ),
        ),
        gelbooruV2DioProvider.overrideWith((ref, config) => dio),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'recovery uses authenticated API ID lookup and retains metadata',
    () async {
      final recovered = await container
          .read(gelbooruV2ClientProvider(config.auth))
          .getPost(42);
      final uri = requests.single.uri;
      expect(uri.scheme, 'https');
      expect(uri.host, 'api.rule34.xxx');
      expect(uri.path, '/index.php');
      expect(uri.queryParameters, containsPair('page', 'dapi'));
      expect(uri.queryParameters, containsPair('s', 'post'));
      expect(uri.queryParameters, containsPair('q', 'index'));
      expect(uri.queryParameters, containsPair('json', '1'));
      expect(uri.queryParameters, containsPair('id', '42'));
      expect(uri.queryParameters, containsPair('user_id', config.login));
      expect(uri.queryParameters, containsPair('api_key', config.apiKey));
      expect(recovered?.id, 42);
      expect(recovered?.fileUrl, post['file_url']);
      expect(recovered?.sampleUrl, post['sample_url']);
      expect(recovered?.previewUrl, post['preview_url']);
      expect(recovered?.tags, post['tags']);
      expect(recovered?.width, 1280);
      expect(recovered?.height, 720);
      expect(recovered?.score, 12);
      expect(recovered?.parentId, 7);
      expect(recovered?.hasNotes, true);
      expect(recovered?.source, post['source']);
      final nativePost = gelbooruV2PostDtoToGelbooruPostNoMetadata(
        recovered!,
        const GelbooruV2ImageUrlResolver(),
      );
      expect(nativePost.id, 42);
      expect(nativePost.originalImageUrl, post['file_url']);
      expect(nativePost.tags, containsAll(['portrait', 'animated']));
      final data = nativePost.booruData as GelbooruV2PostData;
      expect(const GelbooruV2PostCodec().supports(data), isTrue);
      expect(const GelbooruV2PostCodec().encode(data)['hasNotes'], true);
    },
  );

  test('accepts JSON text and an empty result for a removed post', () async {
    final client = container.read(gelbooruV2ClientProvider(config.auth));
    responseData = jsonEncode([post]);
    expect((await client.getPost(42))?.id, 42);
    responseData = '[]';
    expect(await client.getPost(42), isNull);
  });

  for (final invalid in <Object?>[
    '<html>Verification required</html>',
    {'error': 'Invalid API key'},
    null,
    [{}],
    [
      {...post, 'id': 43},
    ],
    [
      {...post, 'file_url': ''},
    ],
    [post, post],
  ]) {
    test(
      'rejects invalid API response $invalid rather than marking removed',
      () async {
        responseData = invalid;
        final client = container.read(gelbooruV2ClientProvider(config.auth));
        await expectLater(client.getPost(42), throwsA(anything));
      },
    );
  }

  for (final (payload, diagnostic) in <(Object, String)>[
    ('<html>Verification required</html>', 'HTML instead of JSON'),
    ('not JSON', 'invalid JSON'),
    ({'error': 'Invalid API key'}, 'Rule34 API error: Invalid API key'),
    (
      [
        {...post, 'id': 43},
      ],
      'post 43 instead of 42',
    ),
    (
      [
        {...post, 'file_url': ''},
      ],
      'no file URL',
    ),
  ]) {
    test('reports a specific diagnostic for $diagnostic', () async {
      responseData = payload;
      final client = container.read(gelbooruV2ClientProvider(config.auth));
      await expectLater(
        client.getPost(42),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'diagnostic',
            contains(diagnostic),
          ),
        ),
      );
    });
  }
}
