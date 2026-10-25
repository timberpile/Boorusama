import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details_parts/types.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
  }) async {
    tester.view
      ..physicalSize = const Size(320, 700)
      ..devicePixelRatio = 1;
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
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('source description fallback wraps long text at ${scale}x', (
      tester,
    ) async {
      final post = TestPost(id: 12).withDetailFacts(
        PostDetailFacts(
          description: List.filled(
            24,
            'Source caption with a long title and description.',
          ).join(' '),
        ),
      );
      await mount(
        tester,
        ProviderScope(
          child: InheritedPost(
            presentationContext: PostPresentationContext.generic(post),
            child: Builder(
              builder: (context) => SizedBox(
                height: 600,
                child: CustomScrollView(
                  slivers: [
                    const PostDetailsUIBuilder().buildPart(
                      context,
                      DetailsPart.artistInfo,
                    )!,
                  ],
                ),
              ),
            ),
          ),
        ),
        scale: scale,
      );
      expect(find.byType(ArtistSection), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ArtistSection)).width,
        lessThanOrEqualTo(320),
      );
    });
    testWidgets(
      'unknown facts do not leak operational file defaults or rating into Details at ${scale}x',
      (tester) async {
        final post = TestPost(
          id: 0,
          width: 800,
          height: 600,
          format: 'jpg',
          fileSize: 900,
        );
        await mount(
          tester,
          FileDetailsSection(
            post: post,
            rating: Rating.unknown,
            initialExpanded: true,
          ),
          scale: scale,
        );
        for (final text in [
          'ID',
          'Rating',
          'Size',
          'Resolution',
          'File format',
          '800x600',
          'JPG',
        ]) {
          expect(find.text(text), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'verified zero bytes and Original geometry appear at ${scale}x',
      (tester) async {
        final post = TestPost(id: 12, width: 300, height: 200, fileSize: 123)
            .withDetailFacts(
              const PostDetailFacts(
                originalByteSize: 0,
                originalWidth: 1800,
                originalHeight: 1200,
                originalFormat: 'png',
              ),
            );
        await mount(
          tester,
          FileDetailsSection(
            post: post,
            rating: Rating.unknown,
            initialExpanded: true,
          ),
          scale: scale,
        );
        expect(find.text('1800x1200'), findsOneWidget);
        expect(find.text('0 B'), findsOneWidget);
        expect(find.text('300x200'), findsNothing);
        expect(find.text('png'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'a pending or failed count omits the metric while a confirmed zero is visible',
    (tester) async {
      await mount(
        tester,
        const SimplePostStatsTile(
          score: 0,
          totalComments: null,
          favCount: null,
        ),
      );
      expect(find.textContaining('Points', findRichText: true), findsOneWidget);
      expect(
        find.textContaining(
          RegExp('comment', caseSensitive: false),
          findRichText: true,
        ),
        findsNothing,
      );
      expect(
        find.textContaining(
          RegExp('favorite', caseSensitive: false),
          findRichText: true,
        ),
        findsNothing,
      );
      await mount(
        tester,
        const SimplePostStatsTile(score: 0, totalComments: 0, favCount: 0),
      );
      expect(
        find.textContaining(
          RegExp('comment', caseSensitive: false),
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          RegExp('favorite', caseSensitive: false),
          findRichText: true,
        ),
        findsOneWidget,
      );
      await mount(tester, const SimplePostStatsTile());
      expect(find.byType(Wrap), findsNothing);
    },
  );
}
