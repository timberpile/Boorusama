import 'package:boorusama/boorus/pixiv/pixiv_repository.dart';
import 'package:boorusama/boorus/pixiv/works/work_creator_avatar.dart';
import 'package:boorusama/core/artists/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../../../core/posts/details/progressive_image_test_utils.dart';
import 'work_test_fixtures.dart';

void main() {
  for (final host in ['i.pximg.net', 's.pximg.net']) {
    testWidgets('creator avatar uses scoped media headers and cache on $host', (
      tester,
    ) async {
      final fixture = _Fixture('https://$host/user-profile/artist.jpg');
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build());
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => fixture.adapter.requests.isNotEmpty,
          reason: 'avatar image request',
        ),
      );
      final sent = fixture.adapter.requests.single;
      expect(sent.headers['Referer'], 'https://www.pixiv.net/');
      for (final secret in ['authorization', 'cookie', 'origin', 'x-api-key']) {
        expect(
          sent.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains(secret)),
        );
      }
      expect(
        tester.widget<BooruImage>(find.byType(BooruImage)).config,
        fixture.access.config!.auth,
      );
      final before = tester.getSize(find.byType(ClipOval));
      fixture.adapter.complete(fixture.url, portraitPng);
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => tester
              .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
              .any((image) => image.image != null),
          reason: 'avatar decode',
        ),
      );
      expect(tester.getSize(find.byType(ClipOval)), before);
      expect(before, const Size(40, 40));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(fixture.build());
      await tester.pumpAndSettle();
      expect(fixture.adapter.requests, hasLength(1));
      expect(fixture.authCalls, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('decoded prepared avatar paints in an inactive page', (
    tester,
  ) async {
    final fixture = _Fixture('https://i.pximg.net/prepared-avatar.jpg');
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.build(active: false, prepare: true));
    await tester.runAsync(
      () => pumpUntil(
        tester,
        () => fixture.adapter.requests.isNotEmpty,
        reason: 'bounded window starts the avatar',
      ),
    );
    fixture.adapter.complete(fixture.url, portraitPng);
    await tester.runAsync(
      () => pumpUntil(
        tester,
        () => tester
            .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
            .any((image) => image.image != null),
        reason: 'the passive artist row paints the decoded image',
      ),
    );
    final dormant = tester
        .widget<ExtendedImage>(find.byType(ExtendedImage))
        .image;
    await tester.pumpWidget(fixture.build(prepare: true));
    await tester.pump();
    expect(
      tester.widget<ExtendedImage>(find.byType(ExtendedImage)).image,
      dormant,
    );
    expect(fixture.adapter.requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'switching the current profile during loading retains the captured Work actor',
    (tester) async {
      final fixture = _Fixture('https://i.pximg.net/profile-switch.jpg');
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build());
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => fixture.adapter.requests.isNotEmpty,
          reason: 'captured actor request',
        ),
      );
      fixture.container.read(fixture.globalProfile.notifier).state =
          fixture.unrelated.config!;
      await tester.pump();
      expect(
        tester.widget<BooruImage>(find.byType(BooruImage)).config,
        fixture.access.config!.auth,
      );
      fixture.adapter.complete(fixture.url, portraitPng);
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => tester
              .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
              .any((image) => image.image != null),
          reason: 'captured actor image completes',
        ),
      );
      expect(
        fixture.container.read(fixture.globalProfile),
        fixture.unrelated.config,
      );
      expect(fixture.adapter.requests, hasLength(1));
      expect(fixture.authCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final url in <String?>[
    null,
    '',
    'broken',
    'http://i.pximg.net/avatar.jpg',
    'https://foreign.test/avatar.jpg',
    'https://i.pximg.net.evil.test/avatar.jpg',
  ]) {
    testWidgets(
      'invalid or absent avatar retains fixed letter fallback: $url',
      (tester) async {
        final fixture = _Fixture(url);
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.build());
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
        expect(find.byType(BooruImage), findsNothing);
        expect(tester.getSize(find.byType(ClipOval)), const Size(40, 40));
        expect(fixture.adapter.requests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed image preserves fallback geometry and artist action at enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = _Fixture('https://i.pximg.net/failed.jpg');
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build(scale: 2));
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => fixture.adapter.requests.isNotEmpty,
          reason: 'failed avatar request',
        ),
      );
      final controller = tester
          .widget<ExtendedImage>(find.byType(ExtendedImage))
          .controller!;
      fixture.adapter.complete(fixture.url, portraitPng, status: 404);
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => controller.loadState.value == LoadState.failed,
          reason: 'failed avatar fallback',
        ),
      );
      expect(tester.getSize(find.byType(ClipOval)), const Size(40, 40));
      await tester.tap(find.byTooltip('View Artist: Artist'));
      expect(fixture.artistTaps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'revoked or inactive access cannot display a late image or borrow another actor',
    (tester) async {
      final fixture = _Fixture('https://i.pximg.net/held.jpg');
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build(active: false));
      await tester.pumpAndSettle();
      expect(fixture.adapter.requests, isEmpty);
      await tester.pumpWidget(fixture.build());
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => fixture.adapter.requests.isNotEmpty,
          reason: 'held avatar request',
        ),
      );
      fixture.container.read(fixture.actor.notifier).state = null;
      await tester.pump();
      fixture.adapter.complete(fixture.url, portraitPng);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(find.byType(BooruImage), findsNothing);
      expect(find.byType(ExtendedRawImage), findsNothing);
      expect(fixture.adapter.requests, hasLength(1));
      // The existing image stream reports cancellation after its last listener
      // detaches. Consume only that expected revoked-request failure.
      expect(
        tester.takeException(),
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Failed to load ${fixture.url}.',
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _Fixture {
  _Fixture(String? avatar) : url = avatar ?? '' {
    container = ProviderContainer(
      overrides: [
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(
            initialConfigs: [access.config!, unrelated.config!],
          ),
        ),
        currentReadOnlyBooruConfigProvider.overrideWith(
          (ref) => ref.watch(globalProfile),
        ),
        contentAccessContextProvider.overrideWith((ref, key) {
          final current = ref.watch(actor);
          return current?.key == key ? current : null;
        }),
        settingsProvider.overrideWithValue(Settings.defaultSettings),
        deviceInfoProvider.overrideWithValue(DeviceInfo.empty()),
        automaticMediaLoadingEnabledProvider.overrideWithValue(true),
        defaultImageCacheManagerProvider.overrideWithValue(cache),
        dioForWidgetProvider.overrideWith((ref, auth) => dio),
        httpHeadersProvider.overrideWith(
          (ref, auth) => {
            'Authorization': 'synthetic',
            'Cookie': 'synthetic',
            'Origin': 'https://www.pixiv.net',
            'X-Api-Key': 'synthetic',
            ...PixivRepository(ref: ref).extraHttpHeaders(auth),
          },
        ),
      ],
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          authCalls++;
          handler.next(request);
        },
      ),
    );
  }
  final String url;
  final access = workAccess();
  final unrelated = workAccess(id: '22222222-2222-4222-8222-222222222222');
  late final globalProfile = StateProvider<BooruConfig>(
    (ref) => access.config!,
  );
  late final actor = StateProvider<ContentAccessContext?>((ref) => access);
  final adapter = ControlledImageAdapter();
  late final dio = Dio()..httpClientAdapter = adapter;
  final cache = TestImageCache({});
  late final ProviderContainer container;
  var authCalls = 0;
  var artistTaps = 0;

  Widget build({bool active = true, double scale = 1, bool prepare = false}) =>
      UncontrolledProviderScope(
        container: container,
        child: testApp(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: PixivWorkAvatarWindow(
              creators: [
                if (prepare)
                  (
                    creator: CreatorRef(
                      displayName: 'Artist',
                      avatar: Uri.tryParse(url),
                    ),
                    access: access,
                  ),
              ],
              child: NavigationActivity(
                active: active,
                child: Consumer(
                  builder: (context, ref, _) => ArtistSection(
                    commentary: const ArtistCommentary.description('Caption'),
                    artistTags: const {'Artist'},
                    source: PostSource.none(),
                    onArtistTap: (_) => artistTaps++,
                    artistAvatarBuilder: pixivWorkCreatorAvatarBuilder(
                      creators: [
                        CreatorRef(
                          displayName: 'Artist',
                          avatar: url.startsWith('http')
                              ? Uri.tryParse(url)
                              : null,
                        ),
                      ],
                      access: ref.watch(actor),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
  void dispose() {
    container.dispose();
    dio.close(force: true);
  }
}
