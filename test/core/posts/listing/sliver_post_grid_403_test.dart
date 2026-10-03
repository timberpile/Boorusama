// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/listing/src/_internal/sliver_post_grid.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_duplicate_checker.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_controller.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  testWidgets('Rule34 403 shows a concise error and a working Retry action', (
    tester,
  ) async {
    var fetchCount = 0;
    final controller = PostGridController<Post>(
      fetcher: (_) {
        fetchCount++;
        return TaskEither.right(const PostResult(posts: [], total: 0));
      },
      blacklistedTagsFetcher: () async => const {},
      mountedChecker: () => true,
      duplicateTracker: PostDuplicateTracker(),
      onError: (_) {},
      debounceDuration: Duration.zero,
    );
    addTearDown(controller.dispose);
    controller.errors.value = ServerError(
      httpStatusCode: 403,
      message: '<html>CAPTCHA challenge</html>',
    );

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: Kurumi.themeFrom(
            KurumiThemeMode.light,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            systemDarkMode: false,
          ),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          ),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPostGrid<Post>(
                  postController: controller,
                  itemBuilder: (_, _) => const SizedBox(),
                  errorTranslator: DefaultAppErrorTranslator(),
                  showRule34ChallengeRecovery: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('403'), findsOneWidget);
    expect(find.byType(MarkdownBody), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('CAPTCHA'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump(const Duration(milliseconds: 20));
    expect(fetchCount, 1);
  });

  testWidgets('another site keeps its existing 403 details without Retry', (
    tester,
  ) async {
    final controller = PostGridController<Post>(
      fetcher: (_) => TaskEither.right(const PostResult(posts: [], total: 0)),
      blacklistedTagsFetcher: () async => const {},
      mountedChecker: () => true,
      duplicateTracker: PostDuplicateTracker(),
      onError: (_) {},
    );
    addTearDown(controller.dispose);
    controller.errors.value = ServerError(
      httpStatusCode: 403,
      message: '<html>Site-specific denial</html>',
    );

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: Kurumi.themeFrom(
            KurumiThemeMode.light,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            systemDarkMode: false,
          ),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          ),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPostGrid<Post>(
                  postController: controller,
                  itemBuilder: (_, _) => const SizedBox(),
                  errorTranslator: DefaultAppErrorTranslator(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('403'), findsOneWidget);
    expect(find.text('<html>Site-specific denial</html>'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
