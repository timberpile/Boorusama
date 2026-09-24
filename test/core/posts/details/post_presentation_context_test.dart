// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details_parts/src/details_ui_builder.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  testWidgets(
    'common UI reads the current post without an exact runtime type',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InheritedPost(
            presentationContext: PostPresentationContext.resolve(
              post: _post(const GelbooruV2PostData(hasNotes: true)),
              presentation: const _NotesPresentation(),
            ),
            child: Builder(
              builder: (context) => Text('${InheritedPost.of(context).id}'),
            ),
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);
    },
  );

  testWidgets('compatible engine UI reads its validated typed payload', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InheritedPost(
          presentationContext: PostPresentationContext.resolve(
            post: _post(const GelbooruV2PostData(hasNotes: true)),
            presentation: const _NotesPresentation(),
          ),
          child: Builder(
            builder: (context) {
              final data = InheritedPost.presentationOf(
                context,
              ).data<GelbooruV2PostData>();
              return Text('${data?.hasNotes}');
            },
          ),
        ),
      ),
    );

    expect(find.text('true'), findsOneWidget);
  });

  testWidgets(
    'incompatible payload selects generic presentation without cast',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InheritedPost(
            presentationContext: PostPresentationContext.resolve(
              post: _post(const EmptyPostData(typeKey: 'other')),
              presentation: const _NotesPresentation(),
            ),
            child: Builder(
              builder: (context) {
                final presentationContext = InheritedPost.presentationOf(
                  context,
                );
                return Text(
                  '${presentationContext.presentation.runtimeType}:'
                  '${presentationContext.data<GelbooruV2PostData>()}',
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('GenericPostPresentation:null'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('generic presentation does not expose engine data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InheritedPost(
          presentationContext: PostPresentationContext.resolve(
            post: _post(const GelbooruV2PostData(hasNotes: true)),
            presentation: const GenericPostPresentation(),
          ),
          child: Builder(
            builder: (context) {
              final data = InheritedPost.presentationOf(
                context,
              ).data<GelbooruV2PostData>();
              return Text('$data');
            },
          ),
        ),
      ),
    );

    expect(find.text('null'), findsOneWidget);
  });
}

Post _post(BooruPostData data) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.gelbooruV2,
    booruId: BooruType.gelbooruV2.id,
    source: 'https://example.com',
  ),
  core: PostCoreData(
    id: 42,
    thumbnailImageUrl: 'thumb',
    sampleImageUrl: 'sample',
    originalImageUrl: 'original',
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
  booruData: data,
);

final class _NotesPresentation implements BooruPostPresentation {
  const _NotesPresentation();

  @override
  PostDetailsWrapperBuilder? get detailsWrapperBuilder => null;

  @override
  bool supports(BooruPostData data) => data is GelbooruV2PostData;

  @override
  PostDetailsUIBuilder detailsBuilder(Post post) =>
      const PostDetailsUIBuilder();
}
