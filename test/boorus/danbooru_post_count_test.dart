import 'package:booru_clients/danbooru.dart';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/posts/count/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/posts/count/providers.dart';
import 'package:boorusama/core/posts/count/widgets.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../core/search/following_topics/following_topic_test_utils.dart';

void main() {
  testWidgets('Safebooru search header shows its nine diives results', (
    tester,
  ) async {
    final safe = BooruConfig.fromJson({
      ...testProfile.toJson(),
      'url': 'https://safebooru.donmai.us',
    });
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.queryParameters['tags'], 'diives rating:g');
            handler.resolve(
              Response<dynamic>(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'counts': {'posts': 9},
                },
              ),
            );
          },
        ),
      );
    addTearDown(() => dio.close(force: true));
    final harness = FollowingTopicHarness(
      profiles: [safe],
      overrides: [
        danbooruClientProvider.overrideWith(
          (ref, auth) => DanbooruClient(baseUrl: auth.url, dio: dio),
        ),
        postCountRepoProvider.overrideWith(
          (ref, config) => ref.watch(danbooruPostCountRepoProvider(config)),
        ),
        postRepoProvider.overrideWith((ref, config) => EmptyPostRepository()),
      ],
    );
    addTearDown(harness.dispose);
    await harness.pump(
      tester,
      CurrentBooruConfigScope(
        config: safe,
        child: const Scaffold(
          body: ResultHeaderWithProvider(
            selectedTagsString: 'diives',
            onRefresh: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('9 Results'), findsOneWidget);
    expect(find.text('388 Results'), findsNothing);
  });

  for (final url in [
    'https://safebooru.donmai.us/',
    'https://safebooru.donmai.us',
    'https://SAFEBOORU.DONMAI.US/',
    'http://safebooru.donmai.us/',
    'https://safebooru.donmai.us:443/',
    'https://danbooru.donmai.us/',
    'https://safebooru.donmai.us.example.com/',
    'https://notsafebooru.donmai.us/',
  ]) {
    final safe = Uri.parse(url).host.toLowerCase() == 'safebooru.donmai.us';
    test('count follows the site restriction for $url', () async {
      final config = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': '00000000-0000-4000-8000-000000000064',
        'url': url,
      });
      String? requestedTags;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              expect(request.path, '/counts/posts.json');
              requestedTags = request.queryParameters['tags'] as String;
              handler.resolve(
                Response<dynamic>(
                  requestOptions: request,
                  statusCode: 200,
                  data: {
                    'counts': {
                      'posts': requestedTags!.split(' ').contains('rating:g')
                          ? 9
                          : 388,
                    },
                  },
                ),
              );
            },
          ),
        );
      addTearDown(() => dio.close(force: true));
      final container = ProviderContainer(
        overrides: [
          danbooruClientProvider.overrideWith((ref, auth) {
            expect(auth, config.auth);
            return DanbooruClient(baseUrl: auth.url, dio: dio);
          }),
        ],
      );
      addTearDown(container.dispose);
      final tags = ['diives'];
      expect(
        await container
            .read(danbooruPostCountRepoProvider(config.search))
            .count(tags),
        safe ? 9 : 388,
      );
      expect(requestedTags, safe ? 'diives rating:g' : 'diives');
      expect(tags, ['diives']);
    });
  }
}
