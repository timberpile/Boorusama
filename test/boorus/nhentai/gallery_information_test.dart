import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/boorus/nhentai/galleries/information.dart';
import 'package:boorusama/boorus/nhentai/galleries/mapper.dart';
import 'package:boorusama/boorus/nhentai/galleries/related.dart';
import 'package:boorusama/boorus/nhentai/nhentai_builder.dart';
import 'package:boorusama/boorus/nhentai/posts/data.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/posts/details/routes.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details/src/providers/media_group_provider.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/details/src/widgets/group_viewer_scope.dart';
import 'package:boorusama/core/posts/details_manager/types.dart';
import 'package:boorusama/core/posts/details_parts/types.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/tags/tag/providers.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/themes/colors/src/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/material.dart';

import 'fixtures.dart';

void main() {
  testWidgets('saved Page details link to its full Gallery', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final access = galleryAccess();
    final config = access.config!;
    final post = nhentaiGalleryPosts(
      NhentaiGalleryDetails.fromJson(galleryJson()),
      access,
      galleryPolicy(),
    ).last;
    const codec = StoredPostCodec();
    const dataCodec = NhentaiPostCodec();
    final saved = codec.decode(
      codec.encode(post, dataCodec: dataCodec),
      dataCodec: dataCodec,
    ) as StoredPostDecodeSuccess;
    DetailsRouteContext<dynamic>? opened;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => InheritedPost(
            presentationContext: PostPresentationContext.generic(saved.post),
            child: Scaffold(
              body: Builder(
                builder: (context) => CustomScrollView(
                  slivers: [
                    NhentaiBuilder().postDetailsUIBuilder.buildPart(
                      context,
                      DetailsPart.parentWork,
                    )!,
                  ],
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/details',
          builder: (_, state) {
            opened = state.extra! as DetailsRouteContext<dynamic>;
            return const Scaffold();
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWithValue(router),
          currentContentAccessKeyProvider.overrideWithValue(access.key),
          contentAccessContextProvider(access.key).overrideWithValue(access),
        ],
        child: TranslationProvider(
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery #101'));
    await tester.pumpAndSettle();
    final gallery = opened!.entries!.single as GroupViewerEntry;
    expect(gallery.summary.reference, nhentaiGalleryReference(access, 101));
    expect(gallery.source?.config, config);
    expect(opened!.posts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gallery tag taps open a typed nhentai search', (tester) async {
    final access = galleryAccess();
    final config = access.config!;
    final details = nhentaiGalleryDetails(
      NhentaiGalleryDetails.fromJson(
        galleryJson(
          tags: [
            {'id': 1, 'type': 'tag', 'name': 'vanilla'},
            {'id': 2, 'type': 'artist', 'name': 'vanilla cream'},
          ],
        ),
      ),
      access,
      galleryPolicy(),
    );
    final entry = GroupViewerEntry(
      summary: details.summary,
      occurrenceId: 0,
      source: ViewerSourceBinding(config),
    );
    SearchParams? opened;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: GroupViewerScope(
              entry: entry,
              child: const SingleChildScrollView(
                child: NhentaiGalleryInformation(),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/search',
          builder: (_, state) {
            opened = SearchParams.fromUri(state.uri);
            return const Scaffold();
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWithValue(router),
          mediaGroupProvider(entry).overrideWith(
            (_) => MediaGroupState(access: access, details: details),
          ),
          booruChipColorsProvider.overrideWithValue(
            BooruChipColors.colorScheme(
              ColorScheme.fromSeed(seedColor: Colors.blue),
            ),
          ),
          booruLoginDetailsProvider(config.auth).overrideWith(
            (_) => const DefaultBooruLoginDetails(
              login: null,
              apiKey: null,
              url: '',
            ),
          ),
          tagColorProvider((config.auth, 'general'))
              .overrideWithValue(Colors.blue),
          tagColorProvider((config.auth, 'artist'))
              .overrideWithValue(Colors.purple),
        ],
        child: TranslationProvider(
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final (name, query) in [
      ('vanilla', 'tag:"vanilla"'),
      ('vanilla cream', 'artist:"vanilla cream"'),
    ]) {
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is TagChip && widget.text == name,
        ),
      );
      await tester.pumpAndSettle();
      expect(opened?.query, isNull);
      expect(opened?.queryType, QueryType.list);
      final tag = opened?.tags?.tags.single;
      expect(tag?.originalTag, query);
      expect(tag?.isRaw, isFalse);
      router.pop();
      await tester.pumpAndSettle();
    }
  });

  test('Gallery layout persists independently of standalone Page layout', () {
    final legacy = LayoutConfigs.fromJson(const {
      'details': [
        {'name': 'fileDetails'},
        {'name': 'parentWork'},
      ],
    });
    expect(legacy.galleryDetails, isNull);
    final galleryOrder = [
      DetailsPart.galleryRelated,
      DetailsPart.galleryTitle,
      DetailsPart.galleryInfo,
      DetailsPart.tags,
    ];
    final saved = legacy.copyWith(
      galleryDetails: () => convertDetailsParts(galleryOrder),
    );
    final restored = LayoutConfigs.fromJsonString(saved.toJsonString())!;
    expect(restored, saved);
    expect(restored.details, legacy.details);
    expect(
      restored.galleryDetails!.map((key) => key.name),
      galleryOrder.map((part) => part.name),
    );
    expect(nhentaiGalleryDetailsUi.full.keys, [
      DetailsPart.toolbar,
      DetailsPart.galleryTitle,
      DetailsPart.galleryInfo,
      DetailsPart.tags,
      DetailsPart.galleryRelated,
      DetailsPart.fileDetails,
    ]);
  });

  testWidgets(
    'related Galleries prepare before Details and survive leaving the canvas',
    (
      tester,
    ) async {
      final access = galleryAccess();
      final policy = galleryPolicy();
      final details = nhentaiGalleryDetails(
        NhentaiGalleryDetails.fromJson(galleryJson()),
        access,
        policy,
      );
      final entry = GroupViewerEntry(
        summary: details.summary,
        occurrenceId: 0,
        source: ViewerSourceBinding(access.config!),
      );
      final recommendations = [
        for (var index = 1; index <= 5; index++)
          nhentaiGallerySummary(
            NhentaiGallerySummary.fromJson({
              'id': 101 + index,
              'english_title': 'Recommendation $index',
            }),
            access,
            policy,
          ),
      ];
      final phase = ValueNotifier(0);
      addTearDown(phase.dispose);
      NhentaiRelatedGalleryCache? cache;
      var requests = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentAccessContextProvider(access.key).overrideWithValue(access),
            nhentaiRelatedGalleriesProvider((access.key, 101)).overrideWith(
              (ref) {
                requests++;
                return recommendations;
              },
            ),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    final results = cache ??= NhentaiRelatedGalleryCache(ref);
                    return ValueListenableBuilder(
                      valueListenable: phase,
                      builder: (context, value, _) {
                        if (value == 2) return const SizedBox.shrink();
                        return NhentaiRelatedGalleryWindow(
                          access: access,
                          galleryId: 101,
                          cache: results,
                          prepare: value == 0,
                          child: value == 0
                              ? const SizedBox.shrink()
                              : GroupViewerScope(
                                  entry: entry,
                                  child: const CustomScrollView(
                                    slivers: [NhentaiRelatedGalleries()],
                                  ),
                                ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text('More Like This'), findsNothing);
      phase.value = 1;
      await tester.pump();
      expect(find.text('Recommendation 5'), findsOneWidget);
      phase.value = 2;
      await tester.pumpAndSettle();
      phase.value = 3;
      await tester.pump();
      expect(find.text('Recommendation 5'), findsOneWidget);
      expect(find.text('Show All'), findsNothing);
      expect(requests, 1);
      cache!.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'saved Gallery details group named tags and show source metadata at 320dp',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const categories = [
        'parody',
        'character',
        'tag',
        'artist',
        'group',
        'language',
        'category',
      ];
      final details = nhentaiGalleryDetails(
        NhentaiGalleryDetails.fromJson(
          galleryJson(
            tags: [
              for (final (index, category) in categories.indexed)
                {'id': index + 1, 'type': category, 'name': 'tag $index'},
              {'id': 81, 'type': 'future', 'name': 'future tag'},
            ],
          ),
        ),
        galleryAccess(),
        galleryPolicy(),
      );
      final auth = BooruConfig.empty.auth;
      final palette = {
        'copyright': Colors.purple,
        'character': Colors.green,
        'general': Colors.blue,
        'artist': Colors.red,
        'meta': Colors.amber,
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booruChipColorsProvider.overrideWithValue(
              BooruChipColors.colorScheme(
                ColorScheme.fromSeed(seedColor: Colors.blue),
              ),
            ),
            booruLoginDetailsProvider(auth).overrideWith(
              (ref) => const DefaultBooruLoginDetails(
                login: null,
                apiKey: null,
                url: '',
              ),
            ),
            for (final entry in palette.entries)
              tagColorProvider((auth, entry.key))
                  .overrideWith((ref) => entry.value),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: NhentaiGalleryInformation(details: details),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uploaded'), findsOneWidget);
      expect(find.text('ID'), findsOneWidget);
      expect(find.text('101'), findsOneWidget);
      expect(find.text('7001'), findsNothing);
      final headings = [
        'Parody',
        'Character',
        'Tags',
        'Artist',
        'Group',
        'Language',
        'Category',
      ];
      final offsets = [
        for (final name in headings) tester.getTopLeft(find.text(name)).dy,
      ];
      expect(offsets, orderedEquals(offsets.toList()..sort()));
      final left = tester.getTopLeft(find.text('Tags')).dx;
      for (final heading in headings) {
        expect(tester.getTopLeft(find.text(heading)).dx, left, reason: heading);
      }
      final chips = {
        for (final chip in tester.widgetList<TagChip>(find.byType(TagChip)))
          chip.text: chip,
      };
      expect(chips['tag 0']?.colorOverride, Colors.purple);
      expect(chips['tag 1']?.colorOverride, Colors.green);
      expect(chips['future tag']?.colorOverride, Colors.blue);
      expect(chips['tag 3']?.colorOverride, Colors.red);
      expect(chips['tag 6']?.colorOverride, Colors.amber);
      for (var index = 0; index < categories.length; index++) {
        final chip = find.byWidget(chips['tag $index']!);
        expect(tester.getTopLeft(chip).dx, left, reason: 'tag $index');
      }
      expect(tester.takeException(), isNull);
    },
  );
}
