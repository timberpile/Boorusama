import 'dart:typed_data';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/iqdb_remote_image.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/iqdb_signature.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:kurumi/material.dart';

import '../support/fakes/test_post.dart';

void main() {
  testWidgets(
    'remote IQDB uses scoped media transport and falls back to original',
    (tester) async {
      final config = BooruConfig.fromJson({
        ...BooruConfig.defaultConfig(
          booruType: BooruType.danbooru,
          url: 'https://danbooru.donmai.us',
          customDownloadFileNameFormat: null,
        ).toJson(),
        'id': '00000000-0000-4000-8000-000000000001',
      });
      final access = ContentAccessContext.profile(
        config: config,
        authEpoch: 1,
        policyEpoch: 1,
      );
      final permitted = StateProvider<bool>((_) => true);
      final source = TestPost(
        id: 42,
        origin: postOriginFromConfig(config),
        sampleImageUrl: 'https://cdn.donmai.us/sample.jpg',
        originalImageUrl: 'https://cdn.donmai.us/original.png',
      );
      final png = image.encodePng(image.Image(width: 8, height: 12));
      final adapter = _MediaAdapter(png);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final container = ProviderContainer(
        overrides: [
          contentAccessContextProvider.overrideWith(
            (ref, key) =>
                ref.watch(permitted) && key == access.key ? access : null,
          ),
          contentPostVisibilityProvider.overrideWith(
            (_, _) => const AsyncData(true),
          ),
          dioForWidgetProvider.overrideWith((_, _) => dio),
          httpHeadersProvider.overrideWith(
            (_, _) => {
              'Authorization': 'secret',
              'Cookie': 'secret',
              'Accept': 'image/*',
            },
          ),
        ],
      );
      addTearDown(container.dispose);
      late WidgetRef ref;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (_, value, _) {
              ref = value;
              return const SizedBox();
            },
          ),
        ),
      );

      final signature = await tester.runAsync(
        () => remoteIqdbSignature(ref, source, access, () => false),
      );
      expect(signature, iqdbSignature(png));
      expect(adapter.requests.map((request) => request.uri.path), [
        '/sample.jpg',
        '/original.png',
      ]);
      for (final request in adapter.requests) {
        expect(request.uri.host, 'cdn.donmai.us');
        expect(request.headers, isNot(contains('Authorization')));
        expect(request.headers, isNot(contains('Cookie')));
        expect(request.headers['Accept'], 'image/*');
      }

      container.read(permitted.notifier).state = false;
      expect(
        await tester.runAsync(
          () => remoteIqdbSignature(ref, source, access, () => false),
        ),
        isNull,
      );
      expect(adapter.requests, hasLength(2));
    },
  );
}

class _MediaAdapter implements HttpClientAdapter {
  _MediaAdapter(this.png);
  final Uint8List png;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.uri.path == '/sample.jpg') {
      return ResponseBody.fromString('Missing sample', 404);
    }
    return ResponseBody.fromBytes(png, 200);
  }

  @override
  void close({bool force = false}) {}
}
