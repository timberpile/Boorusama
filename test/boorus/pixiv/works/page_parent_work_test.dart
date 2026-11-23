import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/pixiv_builder.dart';
import 'package:boorusama/boorus/pixiv/posts/post_codec.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_targets.dart';
import 'package:boorusama/boorus/pixiv/works/page_parent_work_section.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/details/routes.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/details/src/widgets/group_viewer_scope.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_full_info_sheet.dart';
import 'package:boorusama/core/posts/details_manager/src/pages/details_layout_manager_page.dart';
import 'package:boorusama/core/posts/details_manager/src/providers/details_layout_provider.dart';
import 'package:boorusama/core/posts/details_manager/src/routes/routes.dart';
import 'package:boorusama/core/posts/details_manager/types.dart';
import 'package:boorusama/core/posts/details_parts/types.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/pools/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'work_test_fixtures.dart';

void main() {
  for (final width in [320.0, 400.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('snapshot-only Pool section at $width dp, ${scale}x text', (
        tester,
      ) async {
        final harness = await _pump(tester, width: width, scale: scale);
        expect(find.text('Parent Work'), findsOneWidget);
        expect(find.text('Work #456'), findsOneWidget);
        expect(find.text('3 Pages'), findsOneWidget);
        expect(find.byType(PoolTileList<PixivPostData>), findsOneWidget);
        expect(find.byIcon(Symbols.keyboard_arrow_right), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(find.byType(TextButton), findsNothing);
        expect(find.byType(ArtistSection), findsNothing);
        final row = tester.getRect(find.byType(ListTile));
        expect(row.width, lessThanOrEqualTo(width));
        expect(row.height, greaterThanOrEqualTo(48));
        expect(harness.metadataReads, 0);
        expect(harness.bookmarkReads, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final count in [0, 1, 7]) {
    testWidgets('Page snapshot count $count is displayed without inference', (
      tester,
    ) async {
      final access = workAccess();
      final original = pixivWorkPagePosts(work(id: 456), access)[2];
      const codec = PixivPostCodec();
      final post = original.copyWith(
        booruData: codec.decode({
          ...codec.encode(original.pixivData!),
          'pageCount': count,
        }, version: 1),
      );
      await _pump(tester, post: post);
      expect(find.text('Work #456'), findsOneWidget);
      expect(find.text('1 Page'), count == 1 ? findsOneWidget : findsNothing);
      expect(
        find.text('$count Pages'),
        count > 1 ? findsOneWidget : findsNothing,
      );
      expect(
        tester.widget<ListTile>(find.byType(ListTile)).subtitle,
        count == 0 ? isNull : isNotNull,
      );
    });
  }

  for (final id in [0, -1, 9007199254740992]) {
    testWidgets('invalid saved Work ID $id has no actionable parent section', (
      tester,
    ) async {
      final original = pixivWorkPagePosts(work(id: 456), workAccess())[2];
      const codec = PixivPostCodec();
      final harness = await _pump(
        tester,
        post: original.copyWith(
          booruData: codec.decode({
            ...codec.encode(original.pixivData!),
            'illustId': id,
          }, version: 1),
        ),
      );
      expect(find.text('Parent Work'), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(harness.metadataReads, 0);
      expect(harness.bookmarkReads, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'independent section visibility and saved order do not depend on Artist Info',
    (tester) async {
      final harness = await _pump(
        tester,
        parts: {
          DetailsPart.parentWork,
          DetailsPart.tags,
          DetailsPart.artistInfo,
        },
      );
      expect(
        tester.getTopLeft(find.text('Parent Work')).dy,
        lessThan(tester.getTopLeft(find.text('Tags marker')).dy),
      );
      expect(find.byType(ArtistSection), findsOneWidget);
      await harness.showParts(tester, {
        DetailsPart.artistInfo,
        DetailsPart.tags,
      });
      expect(find.byType(ArtistSection), findsOneWidget);
      expect(find.text('Parent Work'), findsNothing);
      expect(find.byType(PixivParentWorkSection), findsNothing);
      await harness.showParts(tester, {
        DetailsPart.tags,
        DetailsPart.parentWork,
      });
      expect(find.byType(ArtistSection), findsNothing);
      expect(
        tester.getTopLeft(find.text('Parent Work')).dy,
        greaterThan(tester.getTopLeft(find.text('Tags marker')).dy),
      );
      expect(harness.metadataReads, 0);
      expect(harness.bookmarkReads, 0);
    },
  );

  testWidgets(
    'navigation uses genuine Work identity, known count and captured actor without saving',
    (tester) async {
      final harness = await _pump(tester);
      await tester.tap(find.text('Work #456'));
      await tester.pumpAndSettle();
      final entry = harness.opened!.entries!.single as GroupViewerEntry;
      expect(entry.summary.reference.sourceKey, 'work:456');
      expect(entry.summary.memberCount, 3);
      expect(entry.source!.config, harness.access.config);
      expect(entry.source!.bookmarkId, isNull);
      expect(entry.summary.cover, isNull);
      expect(harness.metadataReads, 0);
      expect(harness.bookmarkReads, 0);
    },
  );

  testWidgets(
    'revoked source hides section and rejects a previously captured tap',
    (tester) async {
      final harness = await _pump(tester);
      final capturedTap = tester.widget<ListTile>(find.byType(ListTile)).onTap!;
      harness.container.read(harness.current.notifier).state = null;
      capturedTap();
      await tester.pumpAndSettle();
      expect(harness.opened, isNull);
      expect(find.text('Parent Work'), findsNothing);
      expect(harness.metadataReads, 0);
      expect(harness.bookmarkReads, 0);
    },
  );

  for (final unavailable in ['profile', 'site', 'animation', 'work']) {
    testWidgets('no parent section for $unavailable context', (tester) async {
      final access = workAccess();
      var post = pixivWorkPagePosts(
        work(id: 456, type: unavailable == 'animation' ? 'ugoira' : 'manga'),
        access,
      ).first;
      if (unavailable == 'profile' || unavailable == 'site') {
        post = post.copyWith(
          origin: PostOrigin.fromSource(
            booruType: post.origin.booruType,
            booruId: post.origin.booruId,
            source: unavailable == 'site'
                ? 'https://other.example'
                : access.config!.url,
            profileIdHint: unavailable == 'profile'
                ? '22222222-2222-4222-8222-222222222222'
                : access.key.profileId,
          ),
        );
      }
      final harness = await _pump(
        tester,
        post: post,
        workContext: unavailable == 'work',
      );
      expect(find.text('Parent Work'), findsNothing);
      expect(harness.metadataReads, 0);
      expect(harness.bookmarkReads, 0);
    });
  }

  test('legacy saved layouts retain keys and order; defaults expose the independent section', () {
    final layout = LayoutConfigs.fromJson(const {
      'details': [
        {'name': 'tags'},
        {'name': 'artistInfo'},
        {'name': 'toolbar'},
      ],
    });
    final restored = LayoutConfigs.fromJson(layout.toJson());
    expect(restored, layout);
    expect(
      getLayoutParsedParts(details: restored.details, hasPremium: true),
      orderedEquals([
        DetailsPart.tags,
        DetailsPart.artistInfo,
        DetailsPart.toolbar,
      ]),
    );
    final builder = PixivBuilder().postDetailsUIBuilder;
    expect(builder.full.keys, contains(DetailsPart.parentWork));
    expect(
      builder.buildableFullParts.toList().indexOf(DetailsPart.parentWork),
      greaterThan(
        builder.buildableFullParts.toList().indexOf(DetailsPart.fileDetails),
      ),
    );
    expect(parseDetailsPart('parentWork'), DetailsPart.parentWork);
  });

  testWidgets(
    'existing customization UI toggles, orders and saves Parent Work separately',
    (tester) async {
      final native = PixivBuilder().postDetailsUIBuilder;
      List<CustomDetailsPartKey>? saved;
      final params = DetailsLayoutManagerParams(
        details: const [
          CustomDetailsPartKey('artistInfo'),
          CustomDetailsPartKey('tags'),
        ],
        availableParts: native.full.keys.toSet(),
        defaultParts: native.full.keys.toSet(),
        onUpdate: (parts) => saved = parts,
      );
      final container = ProviderContainer(
        overrides: [premiumLayoutPreviewProvider.overrideWith(_PreviewOff.new)],
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: BooruLocalization(
            child: MaterialApp(
              // Match the application bridge used by the legacy reorderables package.
              // ignore: deprecated_member_use
              builder: (context, child) => MaterialUiCompatibilityBridge(
                child: KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.5)),
                    child: child!,
                  ),
                ),
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => InheritedDetailsLayoutManagerParams(
                          params: params,
                          child: const DetailsLayoutManagerPage(),
                        ),
                      ),
                    ),
                    child: const Text('Customize'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey(DetailsPart.parentWork));
      await tester.ensureVisible(row);
      final checkbox = find.descendant(
        of: row,
        matching: find.byType(Checkbox),
      );
      expect(tester.widget<Checkbox>(checkbox).value, isFalse);
      await tester.tap(find.text('Parent Work'));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);
      final notifier = container.read(detailsLayoutProvider(params).notifier);
      final order = container
          .read(detailsLayoutProvider(params))
          .allPartsInOrder;
      notifier.reorder(order.indexOf(DetailsPart.parentWork), 0);
      await tester.pumpAndSettle();
      expect(
        container.read(detailsLayoutProvider(params)).allPartsInOrder.first,
        DetailsPart.parentWork,
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(saved, const [
        CustomDetailsPartKey('parentWork'),
        CustomDetailsPartKey('artistInfo'),
        CustomDetailsPartKey('tags'),
      ]);
      final restored = getLayoutParsedParts(details: saved, hasPremium: true);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      final harness = await _pump(tester, parts: restored!);
      expect(find.text('Parent Work'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Parent Work')).dy,
        lessThan(tester.getTopLeft(find.text('Tags marker')).dy),
      );
      expect(harness.metadataReads, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

class _PreviewOff extends PremiumLayoutPreviewNotifier {
  @override
  LayoutPreviewState build() => const LayoutPreviewState.off();
}

Future<_Harness> _pump(
  WidgetTester tester, {
  double width = 400,
  double scale = 1,
  Post? post,
  Set<DetailsPart> parts = const {DetailsPart.parentWork},
  bool workContext = false,
}) async {
  final access = workAccess();
  final original = pixivWorkPagePosts(work(id: 456), access)[2];
  final saved = PixivPageBookmarkTarget(
    access: access,
    post: original,
  ).draft(currentAccess: access, at: DateTime.utc(2026, 11, 14));
  final current = StateProvider<ContentAccessContext?>((ref) => access);
  final harness = _Harness(
    access,
    current,
    ValueNotifier(parts),
    post ?? saved.post,
  );
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => harness.sheet(workContext)),
      GoRoute(
        path: '/details',
        builder: (_, state) {
          harness.opened = state.extra! as DetailsRouteContext<dynamic>;
          return const Scaffold(body: Text('Parent destination'));
        },
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      routerProvider.overrideWithValue(router),
      currentContentAccessKeyProvider.overrideWithValue(access.key),
      contentAccessContextProvider.overrideWith(
        (ref, key) => ref.watch(current),
      ),
      pixivClientProvider.overrideWith((ref, config) {
        harness.metadataReads++;
        throw StateError('No Pixiv API request for display');
      }),
      contentGroupSourceProvider.overrideWith((ref, key) {
        harness.metadataReads++;
        throw StateError('No Work metadata lookup for display');
      }),
      bookmarkRepoProvider.overrideWith((ref) {
        harness.bookmarkReads++;
        throw StateError('No parent Bookmark lookup for display');
      }),
    ],
  );
  harness.container = container;
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    router.dispose();
    harness.parts.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: BooruLocalization(
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

class _Harness {
  _Harness(this.access, this.current, this.parts, this.post);
  final ContentAccessContext access;
  final StateProvider<ContentAccessContext?> current;
  final ValueNotifier<Set<DetailsPart>> parts;
  final Post post;
  late ProviderContainer container;
  var metadataReads = 0;
  var bookmarkReads = 0;
  DetailsRouteContext<dynamic>? opened;
  Future<void> showParts(WidgetTester tester, Set<DetailsPart> value) async {
    parts.value = value;
    await tester.pumpAndSettle();
  }

  Widget sheet(bool workContext) {
    final native = PixivBuilder().postDetailsUIBuilder;
    Widget body = InheritedPost(
      presentationContext: PostPresentationContext.generic(post),
      child: ValueListenableBuilder(
        valueListenable: parts,
        builder: (context, value, _) => Scaffold(
          body: CustomScrollView(
            slivers: buildPostDetailsInfoSlivers(
              context,
              uiBuilder: PostDetailsUIBuilder(
                full: {
                  ...native.full,
                  DetailsPart.tags: (_) =>
                      const SliverToBoxAdapter(child: Text('Tags marker')),
                },
              ),
              preferredParts: value,
              canCustomize: false,
            ),
          ),
        ),
      ),
    );
    if (workContext) {
      body = GroupViewerScope(
        entry: GroupViewerEntry(
          summary: pixivWorkSummary(work(id: 456), access),
          occurrenceId: 456,
          source: ViewerSourceBinding(access.config!),
        ),
        child: body,
      );
    }
    return body;
  }
}
