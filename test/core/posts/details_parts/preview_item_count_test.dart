import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/posts/post/widgets.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/tags/tag/providers.dart';
import 'package:boorusama/core/themes/colors/providers.dart';

void main() {
  const viewportCases = [
    (name: '320 px', width: 320.0, devicePixelRatio: 1.0),
    (name: '320 px at 2x', width: 320.0, devicePixelRatio: 2.0),
    (name: '900 px', width: 900.0, devicePixelRatio: 1.0),
  ];
  final dataCases = [
    (available: 3, expected: 3, nextBatch: null),
    (available: 6, expected: 6, nextBatch: null),
    (available: 9, expected: 6, nextBatch: 3),
    (available: 12, expected: 6, nextBatch: 6),
    (available: 13, expected: 6, nextBatch: 6),
    (available: 19, expected: 6, nextBatch: 6),
  ];
  final sections = [
    (
      name: 'artist',
      build: () => const DefaultInheritedArtistPostsSection<Post>(),
    ),
    (
      name: 'uploader',
      build: () => const UploaderPostsSection<Post>(
        query: UserColonUploaderQuery('artist'),
      ),
    ),
  ];

  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  for (final section in sections) {
    for (final viewport in viewportCases) {
      for (final c in dataCases) {
        testWidgets(
          '${section.name} section initially renders ${c.expected} of ${c.available} posts at ${viewport.name}',
          (tester) async {
            final posts = List.generate(c.available, _post);
            final harness = _PreviewHarness(
              posts: posts,
              artistTags: const {'artist'},
              width: viewport.width,
              section: section.build(),
            );
            addTearDown(harness.dispose);

            _setViewport(tester, viewport.width, viewport.devicePixelRatio);

            await tester.pumpWidget(harness.build());
            await _pumpUntilGridCount(
              tester,
              c.expected,
              expectedPostWidgets: c.expected,
            );

            final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
            expect(grid.delegate.estimatedChildCount, c.expected);
            expect(find.byType(ImageGridItem), findsNWidgets(c.expected));
            if (c.nextBatch case final count?) {
              expect(find.text(_loadMoreLabel(count)), findsOneWidget);
            } else {
              expect(find.textContaining('Show '), findsNothing);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }

      testWidgets(
        '${section.name} loading placeholders stay at six without a load-more action at ${viewport.name}',
        (tester) async {
          final harness = _PreviewHarness(
            posts: const [],
            artistTags: const {'artist'},
            width: viewport.width,
            section: section.build(),
            keepPostsLoading: true,
          );
          addTearDown(harness.dispose);
          _setViewport(tester, viewport.width, viewport.devicePixelRatio);

          await tester.pumpWidget(harness.build());
          await _pumpUntilGridCount(tester, 6);

          final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
          expect(grid.delegate.estimatedChildCount, 6);
          expect(find.byType(ImageGridItem), findsNothing);
          expect(find.text(_loadMoreLabel(6)), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '${section.name} section reveals six more posts per press and hides the control at the end',
      (tester) async {
        final harness = _PreviewHarness(
          posts: List.generate(19, _post),
          artistTags: const {'artist'},
          width: 320,
          section: section.build(),
        );
        addTearDown(harness.dispose);
        _setViewport(tester, 320, 1);

        await tester.pumpWidget(harness.build());
        await _pumpUntilGridCount(tester, 6, expectedPostWidgets: 6);
        await _tapLoadMore(tester, 6);
        await _pumpUntilGridCount(tester, 12, expectedPostWidgets: 12);
        expect(find.text(_loadMoreLabel(6)), findsOneWidget);

        await _tapLoadMore(tester, 6);
        await _pumpUntilGridCount(tester, 18, expectedPostWidgets: 18);
        expect(find.text(_loadMoreLabel(1)), findsOneWidget);

        await _tapLoadMore(tester, 1);
        await _pumpUntilGridCount(tester, 19, expectedPostWidgets: 19);
        expect(find.textContaining('Show '), findsNothing);
        expect(find.textContaining('Show less'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    final partialBatchCases = [
      (available: 9, firstBatch: 3, secondBatch: null),
      (available: 12, firstBatch: 6, secondBatch: null),
      (available: 13, firstBatch: 6, secondBatch: 1),
    ];
    for (final c in partialBatchCases) {
      testWidgets(
        '${section.name} section progressively reveals the remaining posts from ${c.available}',
        (tester) async {
          final harness = _PreviewHarness(
            posts: List.generate(c.available, _post),
            artistTags: const {'artist'},
            width: 320,
            section: section.build(),
          );
          addTearDown(harness.dispose);
          _setViewport(tester, 320, 1);

          await tester.pumpWidget(harness.build());
          await _pumpUntilGridCount(tester, 6, expectedPostWidgets: 6);
          expect(find.text(_loadMoreLabel(c.firstBatch)), findsOneWidget);

          await _tapLoadMore(tester, c.firstBatch);
          final expectedAfterFirstBatch = c.available < 12 ? c.available : 12;
          await _pumpUntilGridCount(
            tester,
            expectedAfterFirstBatch,
            expectedPostWidgets: expectedAfterFirstBatch,
          );
          if (c.secondBatch case final secondBatch?) {
            expect(find.text(_loadMoreLabel(secondBatch)), findsOneWidget);
            await _tapLoadMore(tester, secondBatch);
            await _pumpUntilGridCount(
              tester,
              c.available,
              expectedPostWidgets: c.available,
            );
          }
          expect(find.textContaining('Show '), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'artist preview resets its visible batch when the artist tag changes',
    (tester) async {
      final harness = _PreviewHarness(
        posts: List.generate(19, _post),
        artistTags: {'artist'},
        width: 320,
        section: const DefaultInheritedArtistPostsSection<Post>(),
      );
      addTearDown(harness.dispose);
      _setViewport(tester, 320, 1);

      await tester.pumpWidget(harness.build());
      await _pumpUntilGridCount(tester, 6, expectedPostWidgets: 6);
      await _tapLoadMore(tester, 6);
      await _pumpUntilGridCount(tester, 12, expectedPostWidgets: 12);

      harness.artistTags
        ..clear()
        ..add('other_artist');
      await tester.pumpWidget(harness.build(post: _post(100)));
      await _pumpUntilGridCount(tester, 6, expectedPostWidgets: 6);

      expect(find.text('other artist'), findsOneWidget);
      expect(find.text(_loadMoreLabel(6)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'uploader preview resets its visible batch when the uploader query changes',
    (tester) async {
      final harness = _PreviewHarness(
        posts: List.generate(19, _post),
        artistTags: const {'artist'},
        width: 320,
        section: const UploaderPostsSection<Post>(
          query: UserColonUploaderQuery('artist'),
        ),
      );
      addTearDown(harness.dispose);
      _setViewport(tester, 320, 1);

      await tester.pumpWidget(harness.build());
      await _pumpUntilGridCount(tester, 6, expectedPostWidgets: 6);
      await _tapLoadMore(tester, 6);
      await _pumpUntilGridCount(tester, 12, expectedPostWidgets: 12);

      await tester.pumpWidget(
        harness.build(
          section: const UploaderPostsSection<Post>(
            query: UserColonUploaderQuery('other_artist'),
          ),
        ),
      );
      await _pumpUntilGridCount(tester, 6, expectedPostWidgets: 6);

      expect(find.text(_loadMoreLabel(6)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'load-more control exposes a localized tap action with a comfortable target',
    (tester) async {
      final harness = _PreviewHarness(
        posts: List.generate(9, _post),
        artistTags: const {'artist'},
        width: 320,
        section: const DefaultInheritedArtistPostsSection<Post>(),
      );
      addTearDown(harness.dispose);
      _setViewport(tester, 320, 1);

      await tester.pumpWidget(harness.build());
      await _pumpUntilGridCount(tester, 6, expectedPostWidgets: 6);
      final label = find.text(_loadMoreLabel(3));
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();

      final tapTarget = find.ancestor(
        of: label,
        matching: find.byType(InkWell),
      );
      expect(tapTarget, findsOneWidget);
      expect(tester.getSize(tapTarget).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .getSemantics(tapTarget)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

String _loadMoreLabel(int count) => 'Show $count more';

Future<void> _tapLoadMore(WidgetTester tester, int count) async {
  final label = find.text(_loadMoreLabel(count));
  expect(label, findsOneWidget);
  await tester.ensureVisible(label);
  await tester.pumpAndSettle();
  final tapTarget = find.ancestor(
    of: label,
    matching: find.byType(InkWell),
  );
  await tester.tap(tapTarget);
  await tester.pumpAndSettle();
}

void _setViewport(WidgetTester tester, double width, double devicePixelRatio) {
  tester.view.physicalSize = Size(
    width * devicePixelRatio,
    2400 * devicePixelRatio,
  );
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpUntilGridCount(
  WidgetTester tester,
  int expected, {
  int expectedPostWidgets = 0,
}) async {
  int? lastGridCount;
  var lastPostWidgetCount = 0;
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final grids = find.byType(SliverGrid);
    lastGridCount = grids.evaluate().isEmpty
        ? null
        : tester.widget<SliverGrid>(grids.first).delegate.estimatedChildCount;
    lastPostWidgetCount = find.byType(ImageGridItem).evaluate().length;
    if (lastGridCount == expected &&
        lastPostWidgetCount == expectedPostWidgets) {
      return;
    }
  }

  fail(
    'Timed out waiting for $expected grid children and '
    '$expectedPostWidgets post widgets; last observed '
    '$lastGridCount grid children and $lastPostWidgetCount post widgets.',
  );
}

class _PreviewHarness {
  _PreviewHarness({
    required this.posts,
    required this.artistTags,
    required this.width,
    required this.section,
    this.keepPostsLoading = false,
  }) : config = BooruConfig.defaultConfig(
         booruType: BooruType.danbooru,
         url: 'https://danbooru.example',
         customDownloadFileNameFormat: null,
       ) {
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWithValue(Settings.defaultSettings),
        colorSchemeProvider.overrideWithValue(
          ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        automaticMediaLoadingEnabledProvider.overrideWithValue(false),
        booruRepoProvider.overrideWith((ref, config) => null),
        gridThumbnailSettingsProvider.overrideWith(
          (ref, config) => const GridThumbnailSettings(
            imageQuality: ImageQuality.low,
            animatedPostsDefaultState: AnimatedPostsDefaultState.static,
            gridSize: GridSize.small,
          ),
        ),
        gridThumbnailUrlGeneratorProvider.overrideWith(
          (ref, config) => const DefaultGridThumbnailUrlGenerator(),
        ),
        artistCharacterGroupProvider.overrideWith(
          () => _ArtistTagNotifier(artistTags),
        ),
        detailsPostsProvider.overrideWith((ref, params) {
          if (keepPostsLoading) return Completer<List<Post>>().future;
          return Future.value(posts);
        }),
      ],
    );
  }

  final List<Post> posts;
  final Set<String> artistTags;
  final double width;
  final Widget section;
  final bool keepPostsLoading;
  final BooruConfig config;
  late final ProviderContainer container;

  Widget build({Widget? section, Post? post}) => UncontrolledProviderScope(
    container: container,
    child: BooruLocalization(
      child: MaterialApp(
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: child!,
        ),
        home: CurrentBooruConfigScope(
          config: config,
          child: InheritedPost(
            presentationContext: PostPresentationContext.generic(
              post ?? _post(99),
            ),
            child: PostDetailsSheetConstraints(
              maxWidth: width,
              child: CustomScrollView(
                slivers: [section ?? this.section],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  void dispose() => container.dispose();
}

class _ArtistTagNotifier extends ArtistCharacterNotifier {
  _ArtistTagNotifier(this.tags);

  final Set<String> tags;

  @override
  FutureOr<ArtistCharacterGroup> build(ArtistCharacterGroupParams arg) =>
      ArtistCharacterGroup(characterTags: const {}, artistTags: tags);
}

Post _post(int id) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.danbooru,
    booruId: BooruType.danbooru.id,
    source: 'https://danbooru.example',
  ),
  core: PostCoreData(
    id: id,
    thumbnailImageUrl: 'https://danbooru.example/$id.jpg',
    sampleImageUrl: 'https://danbooru.example/$id.jpg',
    originalImageUrl: 'https://danbooru.example/$id.jpg',
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 300,
    height: 200,
    format: 'jpg',
    md5: '$id',
    fileSize: 1,
    duration: 0,
    tags: const {},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
  ),
  booruData: const EmptyPostData(typeKey: 'test'),
);
