import 'dart:async';

import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/boorus/nhentai/availability.dart';
import 'package:boorusama/boorus/nhentai/client_provider.dart';
import 'package:boorusama/boorus/nhentai/galleries/source.dart';
import 'package:boorusama/boorus/registry.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/cache/persistent/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/posts/links/boorusama_post_link.dart';
import 'package:boorusama/core/posts/links/linked_post_provider.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes/memory_repositories.dart';
import 'fixtures.dart';

void main() {
  for (final multiple in [false, true]) {
    test(
      'a shared Page loads with the selected profile (multiple: $multiple)',
      () async {
        final config = galleryAccess().config!;
        final components = createBooruRegistry();
        final db = BooruDb(
          boorus: {BooruType.nhentai: components.parseFromConfig('nhentai')},
        );
        final received = Completer<void>();
        final release = Completer<void>();
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) async {
                received.complete();
                await release.future;
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: galleryJson(),
                  ),
                );
              },
            ),
          );
        addTearDown(() => dio.close(force: true));
        final container = ProviderContainer(
          overrides: [
            nhentaiAvailableProvider.overrideWithValue(true),
            booruConfigProvider.overrideWith(
              () => BooruConfigNotifier(
                initialConfigs: [
                  if (multiple)
                    BooruConfig.fromJson({
                      ...config.toJson(),
                      'id': '22222222-2222-4222-8222-222222222222',
                    }),
                  config,
                ],
              ),
            ),
            booruEngineRegistryProvider.overrideWith(
              (ref) => ref.watch(
                booruInitEngineProvider((db: db, registry: components)),
              ),
            ),
            blacklistTagsProvider(config.filter)
                .overrideWith((_) => Future.value(<String>{})),
            persistentCacheStoreProvider.overrideWithValue(
              MemoryPersistentCacheStore(),
            ),
            nhentaiClientProvider(config.auth)
                .overrideWithValue(NhentaiClient(dio: dio)),
            nhentaiMediaPolicyProvider(config.auth)
                .overrideWith((_) => galleryPolicy()),
          ],
        );
        addTearDown(container.dispose);
        final link = BoorusamaPostLink.parse(
          'boorusama://post/open?v=1&engine=nhentai&site=https%3A%2F%2Fnhentai.net&key=gallery-page%3A101%3A3',
        );
        final provider = linkedPostProvider((link, config));
        final observer = container.listen(provider, (_, _) {});
        addTearDown(observer.close);
        final result = container.read(provider.future);
        await Future.any<void>([received.future, result.then((_) {})]);
        await container.pump();
        release.complete();
        final page = await result;
        expect(page?.origin.profileIdHint, config.id);
        expect(link.matches(page!), isTrue);
      },
    );
  }

  for (final blocked in [false, true]) {
    test(
      'registered configured nhentai source enforces real blacklist ($blocked)',
      () async {
        final config = galleryAccess().config!;
        final components = createBooruRegistry();
        final db = BooruDb(
          boorus: {BooruType.nhentai: components.parseFromConfig('nhentai')},
        );
        final repository = MemoryGlobalBlacklistedTagRepository();
        await repository.replaceAll([
          BlacklistedTag(
            id: 1,
            name: blocked ? 'fixture' : 'blocked',
            isActive: true,
            createdDate: DateTime.utc(2026),
            updatedDate: DateTime.utc(2026),
          ),
        ]);
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (request, handler) {
                expect(request.uri.path, '/api/v2/galleries/101');
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: request,
                    statusCode: 200,
                    data: galleryJson(),
                  ),
                );
              },
            ),
          );
        addTearDown(() => dio.close(force: true));
        final container = ProviderContainer(
          overrides: [
            nhentaiAvailableProvider.overrideWithValue(true),
            booruConfigProvider.overrideWith(
              () => BooruConfigNotifier(initialConfigs: [config]),
            ),
            booruEngineRegistryProvider.overrideWith(
              (ref) => ref.watch(
                booruInitEngineProvider((db: db, registry: components)),
              ),
            ),
            globalBlacklistedTagRepoProvider.overrideWith(
              (ref) => Future.value(repository),
            ),
            persistentCacheStoreProvider.overrideWithValue(
              MemoryPersistentCacheStore(),
            ),
            loggerProvider.overrideWithValue(
              ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
            ),
            nhentaiClientProvider.overrideWith(
              (ref, auth) => NhentaiClient(dio: dio),
            ),
          ],
        );
        addTearDown(container.dispose);
        final accessHold = container.listen(
          contentProfileAccessProvider(config.id),
          (_, _) {},
        );
        addTearDown(accessHold.close);
        await container.read(blacklistTagsProvider(config.filter).future);
        await container.pump();
        final access = container.read(contentProfileAccessProvider(config.id))!;
        final sourceHold = container.listen(
          contentGroupSourceProvider(access.key),
          (_, _) {},
        );
        addTearDown(sourceHold.close);
        final source = container.read(
          contentGroupSourceProvider(access.key),
        ) as NhentaiGallerySource;
        if (blocked) {
          await expectLater(source.fetchGallery(101), throwsStateError);
        } else {
          expect((await source.fetchGallery(101)).id, 101);
        }
      },
    );
  }
}
