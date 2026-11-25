import 'dart:async';
import 'dart:io';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/network/providers.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/local_media/local_media_models.dart';
import 'package:boorusama/core/local_media/local_media_providers.dart';
import 'package:boorusama/core/local_media/local_media_reference.dart';
import 'package:boorusama/core/local_media/local_media_thumbnail.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_media.dart';
import 'package:boorusama/core/posts/details_pageview/src/post_details_page_view_controller.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_item.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../posts/details/progressive_image_test_utils.dart' show lowerPng;

void main() {
  testWidgets('reopening a decoded local file keeps the viewer clean', (
    tester,
  ) async {
    final reference = LocalMediaReference.parse('a' * 64);
    final directory = Directory.systemTemp.createTempSync('local-media-reopen');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/fixture.png')
      ..writeAsBytesSync(lowerPng);
    final item = LocalMediaItem(
      id: 1,
      reference: reference,
      md5: '',
      format: LocalMediaFormat.png,
      byteSize: lowerPng.length,
      importedAt: DateTime.utc(2026),
      probe: (width: 1, height: 1, durationMs: null),
      tags: const [],
      rating: Rating.unknown,
    );
    final pager = PostDetailsPageViewController(
      initialPage: 0,
      totalPage: 1,
      checkIfLargeScreen: () => false,
    );
    addTearDown(pager.dispose);
    final controllers = [ExtendedImageController(), ExtendedImageController()];
    for (final controller in controllers) {
      addTearDown(controller.dispose);
    }
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localMediaPresentationProvider(reference).overrideWith(
            (_) => Stream.value((item: item, file: file)),
          ),
        ],
        child: BooruLocalization(
          child: MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(),
          ),
        ),
      ),
    );

    await tester.runAsync(
      () =>
          precacheImage(FileImage(file), tester.element(find.byType(Scaffold))),
    );
    await tester.pump();
    for (final controller in controllers) {
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Center(
            child: PostMedia(
              post: item.toPost(),
              config: BooruConfig.empty.auth,
              viewer: BooruConfig.empty.viewer,
              imageUrlBuilder: null,
              mediaAspectRatioBuilder: null,
              videoAspectRatioBuilder: null,
              placeholderMediaBuilder: null,
              controller: pager,
              imageController: controller,
              imageCacheManager: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(controller.loadState.value, LoadState.completed);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'Local Media relinks without remote access and fits the still image to the viewer',
    (tester) async {
      final reference = LocalMediaReference.parse(List.filled(64, 'a').join());
      final folder = Directory.systemTemp.createTempSync('local-media-grid');
      addTearDown(() => folder.deleteSync(recursive: true));
      final file = File('${folder.path}/fixture.png')
        ..writeAsBytesSync(lowerPng);
      final changes = StreamController<LocalMediaPresentation?>();
      addTearDown(changes.close);
      final container = ProviderContainer(
        overrides: [
          contentAccessRequiredProvider.overrideWithValue(true),
          networkSettingsProvider.overrideWith(
            (_, _) => throw StateError(
              'A local reference must avoid remote settings',
            ),
          ),
          localMediaPresentationProvider(reference).overrideWith(
            (_) => changes.stream,
          ),
        ],
      );
      addTearDown(container.dispose);
      final pager = PostDetailsPageViewController(
        initialPage: 0,
        totalPage: 1,
        checkIfLargeScreen: () => false,
      );
      addTearDown(pager.dispose);
      final post = localMediaPost(reference);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: BooruLocalization(
            child: MaterialApp(
              home: Center(
                child: SizedBox(
                  width: 180,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PostGridImage(
                        post: post,
                        media: const GridThumbnailMedia(
                          url: '',
                          aspectRatio: 1,
                        ),
                        config: BooruConfig.empty.auth,
                      ),
                      SizedBox(
                        height: 220,
                        child: PostMedia(
                          post: post,
                          config: BooruConfig.empty.auth,
                          viewer: BooruConfig.empty.viewer,
                          imageUrlBuilder: null,
                          mediaAspectRatioBuilder: null,
                          videoAspectRatioBuilder: null,
                          placeholderMediaBuilder: null,
                          controller: pager,
                          imageCacheManager: null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      changes.add(null);
      await tester.pump();
      expect(find.byType(LocalMediaUnavailable), findsNWidgets(2));
      final delivered = Completer<void>();
      final subscription = container.listen(
        localMediaPresentationProvider(reference),
        (_, state) {
          if (state.valueOrNull?.file == file && !delivered.isCompleted) {
            delivered.complete();
          }
        },
      );
      addTearDown(subscription.close);
      changes.add((
        item: LocalMediaItem(
          id: 47,
          reference: reference,
          md5: '',
          format: LocalMediaFormat.png,
          byteSize: lowerPng.length,
          importedAt: DateTime.utc(2026),
          probe: (width: 1, height: 1, durationMs: null),
          tags: const [],
          rating: Rating.unknown,
        ),
        file: file,
      ));
      await delivered.future;
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(tester.getSize(find.byType(ExtendedImage)), const Size(180, 180));
      expect(find.byType(LocalMediaUnavailable), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
