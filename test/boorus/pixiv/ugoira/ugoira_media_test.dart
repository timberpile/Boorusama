import 'dart:async';

import 'package:boorusama/boorus/pixiv/pixiv_builder.dart';
import 'package:boorusama/boorus/pixiv/ugoira/ugoira_frames.dart';
import 'package:boorusama/boorus/pixiv/ugoira/ugoira_player.dart';
import 'package:boorusama/boorus/pixiv/ugoira/ugoira_source.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/post/widgets.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../works/work_test_fixtures.dart';

void main() {
  testWidgets(
    'only an active, authorized Ugoira loads from its pinned source',
    (
      tester,
    ) async {
      final access = workAccess();
      final accessState = StateProvider<ContentAccessContext?>((ref) => access);
      final selection = ValueNotifier(false);
      addTearDown(selection.dispose);
      final requests = <CancelToken>[];
      final progressCallbacks = <ValueChanged<double?>>[];
      final pending = Completer<PreparedPixivUgoira>();
      final presentation = PixivBuilder().postPresentation;
      final decorator =
          (presentation as TypedBooruPostPresentation).detailsImageBuilder!;
      final post = pixivWorkPagePosts(
        work(id: 122, pageCount: 1, type: 'ugoira'),
        access,
      ).single;

      final container = ProviderContainer(
        overrides: [
          currentContentAccessKeyProvider.overrideWithValue(access.key),
          contentAccessContextProvider.overrideWith(
            (ref, key) => ref.watch(accessState),
          ),
          contentPostVisibilityProvider.overrideWith(
            (ref, request) => const AsyncData(true),
          ),
          pixivUgoiraLoaderProvider.overrideWith((ref, key) {
            expect(key, access.key);
            return (id, token, onDownloadProgress) {
              expect(id, 122);
              requests.add(token);
              progressCallbacks.add(onDownloadProgress);
              return pending.future;
            };
          }),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: [access.config!]),
          ),
          settingsProvider.overrideWithValue(Settings.defaultSettings),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: ValueListenableBuilder(
                  valueListenable: selection,
                  builder: (context, active, child) => decorator(
                    post: post,
                    config: access.config!,
                    active: active,
                    poster: child!,
                  ),
                  child: const SizedBox(width: 220, height: 180),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<PixivUgoiraPlayer>(find.byType(PixivUgoiraPlayer)).active,
        isFalse,
      );
      expect(requests, isEmpty);

      selection.value = true;
      await tester.pump();
      expect(find.byType(PixivUgoiraPlayer), findsOneWidget);
      expect(requests, hasLength(1));

      selection.value = false;
      await tester.pump();
      await tester.pump();
      expect(requests.single.isCancelled, isTrue);
      expect(
        tester.widget<PixivUgoiraPlayer>(find.byType(PixivUgoiraPlayer)).active,
        isFalse,
      );

      selection.value = true;
      await tester.pump();
      expect(requests, hasLength(2));
      progressCallbacks.first(0.75);
      await tester.pump();
      final spinner = find.byType(CircularProgressIndicator);
      expect(tester.widget<CircularProgressIndicator>(spinner).value, isNull);
      progressCallbacks.last(0.5);
      await tester.pump();
      expect(tester.widget<CircularProgressIndicator>(spinner).value, 0.5);

      container.read(accessState.notifier).state = null;
      await tester.pump();
      await tester.pump();
      expect(requests.last.isCancelled, isTrue);
      expect(
        tester.widget<PixivUgoiraPlayer>(find.byType(PixivUgoiraPlayer)).active,
        isFalse,
      );
    },
  );

  testWidgets('a narrow Ugoira card uses the normal GIF badge', (tester) async {
    final post = pixivWorkPagePosts(
      work(id: 122, pageCount: 1, type: 'ugoira'),
      workAccess(),
    ).single;
    expect(post.isGif, isFalse);
    expect(post.isVideo, isFalse);
    expect(post.showsGifBadge, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SizedBox(
                width: 90,
                height: 100,
                child: ImageGridItem(
                  isGif: post.showsGifBadge,
                  image: const ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final badge = find.byIcon(Symbols.gif);
    expect(badge, findsOneWidget);
    final bounds = tester.getRect(find.byType(ImageGridItem));
    expect(tester.getTopLeft(badge).dx - bounds.left, lessThan(16));
    expect(tester.getTopLeft(badge).dy - bounds.top, lessThan(16));
    expect(tester.takeException(), isNull);
  });
}
