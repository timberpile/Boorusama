// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  setUpAll(() async {
    await ensureI18nInitialized('en-US');
  });

  testWidgets('shows the localized upload date when it is available', (
    tester,
  ) async {
    final createdAt = DateTime.now().subtract(const Duration(days: 8));

    await tester.pumpWidget(
      _TestApp(
        post: _post(createdAt: createdAt),
      ),
    );

    expect(find.text('Upload date'), findsOneWidget);
    expect(find.text(createdAt.fuzzify()), findsOneWidget);
  });

  testWidgets('omits the upload date when it is unavailable', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        post: _post(),
      ),
    );

    expect(find.text('Upload date'), findsNothing);
  });
}

final class _TestApp extends StatelessWidget {
  const _TestApp({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return BooruLocalization(
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
          body: FileDetailsSection(
            post: post,
            rating: post.rating,
            initialExpanded: true,
          ),
        ),
      ),
    );
  }
}

Post _post({DateTime? createdAt}) => Post(
  origin: PostOrigin.forBooruType(BooruType.danbooru),
  core: PostCoreData(
    id: 1,
    createdAt: createdAt,
    thumbnailImageUrl: '',
    sampleImageUrl: '',
    originalImageUrl: '',
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 1,
    height: 1,
    format: 'jpg',
    md5: '',
    fileSize: 0,
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
