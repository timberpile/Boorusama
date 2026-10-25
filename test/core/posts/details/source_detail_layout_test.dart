import 'package:boorusama/boorus/registry.g.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:boorusama/core/posts/details_parts/types.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../support/fakes/test_post.dart';

const _types = [
  BooruType.danbooru,
  BooruType.gelbooru,
  BooruType.gelbooruV1,
  BooruType.gelbooruV2,
  BooruType.moebooru,
  BooruType.e621,
  BooruType.zerochan,
  BooruType.sankaku,
  BooruType.philomena,
  BooruType.shimmie2,
  BooruType.szurubooru,
  BooruType.hydrus,
  BooruType.animePictures,
  BooruType.hybooru,
  BooruType.eshuushuu,
  BooruType.nozomi,
  BooruType.pixiv,
];

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));
  final provider = Provider((ref) {
    final registry = createBooruRegistry();
    return {
      for (final type in _types)
        type: registry
            .createEngine(registry.getParser(type)!.parse(), ref)
            .builder
            .postDetailsUIBuilder,
    };
  });

  for (final type in _types) {
    test('$type default common details follow Danbooru order', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final builders = container.read(provider);
      final reference = builders[BooruType.danbooru]!.full.keys.toList();
      final parts = builders[type]!.buildableFullParts.toList();
      expect(parts, containsAll([DetailsPart.artistInfo, DetailsPart.stats]));
      final shared = parts.where(reference.contains).toSet();
      expect(
        parts.where(shared.contains),
        orderedEquals(reference.where(shared.contains)),
      );
    });
  }

  for (final type in [BooruType.gelbooru, BooruType.gelbooruV2]) {
    for (final scale in [1.0, 2.0]) {
      for (final custom in [false, true]) {
        testWidgets('$type stats placement (scale=$scale, custom=$custom)', (
          tester,
        ) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final native = container.read(provider)[type]!;
          // Keep the engine's real section registration and shared statistics;
          // unrelated sections use markers instead of starting API requests.
          final builder = PostDetailsUIBuilder(
            full: {
              for (final part in native.full.keys)
                part: (_) => SliverToBoxAdapter(
                  child: SizedBox(height: 36, child: Text(part.name)),
                ),
            },
          );
          final post = TestPost(id: 12).withDetailFacts(
            const PostDetailFacts(score: 0, commentCount: 0),
          );
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          await tester.pumpWidget(
            BooruLocalization(
              child: MaterialApp(
                theme: Kurumi.themeFrom(
                  KurumiThemeMode.light,
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                  systemDarkMode: false,
                ),
                builder: (context, child) => KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                ),
                home: Scaffold(
                  body: InheritedPost(
                    presentationContext: PostPresentationContext.generic(post),
                    child: PostDetailsFullInfoSheet(
                      sheetState: SheetState.expanded,
                      uiBuilder: builder,
                      canCustomize: false,
                      preferredParts: custom
                          ? {
                              DetailsPart.fileDetails,
                              DetailsPart.tags,
                              DetailsPart.stats,
                              DetailsPart.toolbar,
                            }
                          : builder.buildableFullParts,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final statsY = tester.getTopLeft(find.byType(SimplePostStatsTile)).dy;
          final tagsY = tester.getTopLeft(find.text(DetailsPart.tags.name)).dy;
          final fileY = tester
              .getTopLeft(find.text(DetailsPart.fileDetails.name))
              .dy;
          expect(statsY, custom ? greaterThan(tagsY) : lessThan(tagsY));
          expect(statsY, custom ? greaterThan(fileY) : lessThan(fileY));
          expect(
            find.textContaining('Points', findRichText: true),
            findsOneWidget,
          );
          expect(
            find.textContaining('Comments', findRichText: true),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              RegExp('favorite', caseSensitive: false),
              findRichText: true,
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
