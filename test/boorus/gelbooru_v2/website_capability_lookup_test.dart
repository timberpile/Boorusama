import 'dart:convert';
import 'dart:io';

import 'package:booru_clients/core.dart';
import 'package:booru_clients/generated.dart';
import 'package:booru_clients/gelbooru.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/boorus/gelbooru_v2/client_provider.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2_provider.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/profile_import_projection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/sources/profile_export_sanitizer.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  final registered = GelbooruV2Config.siteCapabilities(
    'https://realbooru.com/',
  );
  for (final url in [
    'https://realbooru.com',
    'https://REALBOORU.COM/',
    'https://realbooru.com:443/',
    'https://realbooru.com///',
    'https://realbooru.com/?view=public#home',
    'https://synthetic-user:synthetic-pass@realbooru.com/',
  ]) {
    test('retains registered Realbooru parsers for $url', () {
      expect(GelbooruV2Config.siteCapabilities(url), same(registered));
      expect(
        registered.overrides[BooruFeatureId.posts]?.parserStrategy,
        'parseRbPostsHtml',
      );
      expect(
        registered.overrides[BooruFeatureId.post]?.parserStrategy,
        'parseRbPostHtml',
      );
      expect(
        registered.overrides[BooruFeatureId.tags]?.parserStrategy,
        'parseRbTagsHtml',
      );
    });
  }
  for (final url in [
    'https://other.example/',
    'https://realbooru.com.evil.example/',
    'https://www.realbooru.com/',
    'https://realbooru.com:444/',
    'http://realbooru.com/',
    'https://realbooru.com/installation/',
    'https://realbooru.com/Installation/',
    'https://realbooru.com:80/',
    'not a URL',
    'https://[invalid',
  ]) {
    test('keeps unregistered website $url on generic capabilities', () {
      final capabilities = GelbooruV2Config.siteCapabilities(url);
      expect(capabilities.overrides, isEmpty);
      expect(capabilities.siteUrl, url);
    });
  }

  test(
    'credential-free export copied as a new profile retains real client search and recovery',
    () async {
      final presetUrl = BooruYamlConfigs.gelbooruV2.sites
          .singleWhere((site) => site.url.contains('realbooru.com'))
          .url;
      final preset = BooruConfig.defaultConfig(
        booruType: BooruType.gelbooruV2,
        url: presetUrl,
        customDownloadFileNameFormat: null,
      );
      final original = BooruConfig.fromJson({
        ...preset.toJson(),
        'id': '00000000-0000-4000-8000-000000000001',
        'apiKey': 'synthetic-secret',
        'login': 'synthetic-account',
      });
      final encoded = const ProfileExportSanitizer().sanitizeExportJson(
        jsonEncode({
          'data': [original.toJson()],
        }),
        false,
      );
      final payload = jsonDecode(encoded) as Map<String, dynamic>;
      final imported = BooruConfig.fromJson(
        (payload['data'] as List).single as Map<String, dynamic>,
      );
      const destinationId = '00000000-0000-4000-8000-000000000042';
      final projection = const ProfileImportProjector().project(
        imported: [imported],
        local: [original],
        resolution: ResolvedImportSource(
          id: 'profiles',
          action: ImportAction.configureItems,
          items: [
            ResolvedImportItem(
              id: 'profile:${original.id}',
              action: ImportAction.copy,
            ),
          ],
        ),
        credentialsIncluded: payload['credentialsIncluded'] as bool,
        copyIds: {original.id: destinationId},
      );
      final copied = projection.profiles.singleWhere(
        (p) => p.id == destinationId,
      );
      expect(copied.url, 'https://realbooru.com');
      expect(copied.apiKey, isNull);
      expect(copied.login, isNull);
      expect(projection.profiles.first, original);
      expect(original.apiKey, 'synthetic-secret');
      expect(projection.destinationIds, {original.id: destinationId});
      final originalOrigin = PostOrigin.fromSource(
        booruType: BooruType.gelbooruV2,
        booruId: BooruType.gelbooruV2.id,
        source: original.url,
      );
      final copiedOrigin = PostOrigin.fromSource(
        booruType: BooruType.gelbooruV2,
        booruId: BooruType.gelbooruV2.id,
        source: copied.url,
      );
      expect(copiedOrigin, originalOrigin);

      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              final isSearch = options.uri.queryParameters['s'] == 'list';
              final html = File(
                'test/boorus/gelbooru_v2/fixtures/${isSearch ? 'realbooru_search_result.html' : 'realbooru_post.html'}',
              ).readAsStringSync();
              handler.resolve(
                Response<String>(
                  requestOptions: options,
                  data: isSearch
                      ? html
                      : '$html<div id="tagLink"><a class="tag-type-general">portrait</a></div>',
                  statusCode: 200,
                ),
              );
            },
          ),
        );
      final container = ProviderContainer(
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
      addTearDown(container.dispose);
      final client = container.read(gelbooruV2ClientProvider(copied.auth));
      expect(client.paginationType, PaginationType.offset);
      expect(client.fixedLimit, 42);
      final listing = await client.getPosts(page: 2, tags: ['portrait']);
      expect(listing.posts, hasLength(1));
      expect(requests.first.uri.queryParameters['pid'], '42');
      expect(requests.first.uri.queryParameters['tags'], 'portrait');
      final recovered = await client.getPost(42);
      expect(
        recovered?.fileUrl,
        'https://realbooru.com/images/ab/cd/0123456789abcdef0123456789abcdef.jpeg',
      );
      expect(recovered?.fileUrl, isNot(listing.posts.single.fileUrl));
      final tags = await client.getTagsFromPostId(postId: 42);
      expect(tags.single.name, 'portrait');
      expect(
        requests.every((r) => !r.uri.queryParameters.containsKey('api_key')),
        isTrue,
      );
    },
  );
}
