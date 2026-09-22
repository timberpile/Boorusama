// Package imports:
import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/details_parts/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  const nativePresentation = _NativePresentation();
  const codec = _NativeDataCodec();
  const capability = BooruPostCapability<_NativeData>(
    booruType: BooruType.danbooru,
    codec: codec,
    presentation: nativePresentation,
  );

  test('matching origin and payload select the native capability', () {
    final origin = _origin(BooruType.danbooru);
    const data = _NativeData();

    expect(capability.codecFor(origin, data), same(codec));
    expect(
      capability.presentationFor(origin, data),
      same(nativePresentation),
    );
  });

  test('a different origin engine selects generic presentation', () {
    final origin = _origin(BooruType.e621);
    const data = _NativeData();

    expect(capability.codecFor(origin, data), isNull);
    expect(
      capability.presentationFor(origin, data),
      isA<GenericPostPresentation>(),
    );
  });

  test('an incompatible payload selects generic presentation', () {
    final origin = _origin(BooruType.danbooru);
    const data = _ForeignData();

    expect(capability.codecFor(origin, data), isNull);
    expect(
      capability.presentationFor(origin, data),
      isA<GenericPostPresentation>(),
    );
  });

  test('generic presentation exposes only common detail sections', () {
    const presentation = GenericPostPresentation();

    final details = presentation.detailsBuilder(_post());

    expect(details.preview, isEmpty);
    expect(details.full, isEmpty);
  });
}

PostOrigin _origin(BooruType type) => PostOrigin.fromSource(
  booruType: type,
  booruId: type.id,
  source: 'https://example.com/',
);

UnifiedPost _post() => UnifiedPost(
  origin: _origin(BooruType.unknown),
  core: PostCoreData(
    id: 1,
    thumbnailImageUrl: '',
    sampleImageUrl: '',
    originalImageUrl: '',
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 0,
    height: 0,
    format: '',
    md5: '',
    fileSize: 0,
    duration: kNoduration,
    tags: const {},
    rating: Rating.unknown,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
  ),
  booruData: const UnknownPostData(
    typeKey: 'unknown',
    schemaVersion: 1,
    custom: {},
    reason: UnknownPostDataReason.unavailableCodec,
  ),
);

final class _NativeData extends Equatable implements BooruPostData {
  const _NativeData();

  @override
  int get schemaVersion => 1;

  @override
  String get typeKey => 'native';

  @override
  List<Object?> get props => const [];
}

final class _ForeignData extends Equatable implements BooruPostData {
  const _ForeignData();

  @override
  int get schemaVersion => 1;

  @override
  String get typeKey => 'foreign';

  @override
  List<Object?> get props => const [];
}

final class _NativeDataCodec implements BooruPostDataCodec<_NativeData> {
  const _NativeDataCodec();

  @override
  int get currentVersion => 1;

  @override
  String get typeKey => 'native';

  @override
  _NativeData decode(
    Map<String, Object?> json, {
    required int version,
  }) => const _NativeData();

  @override
  Map<String, Object?> encode(_NativeData data) => const {};

  @override
  bool supports(BooruPostData data) => data is _NativeData;
}

final class _NativePresentation implements BooruPostPresentation {
  const _NativePresentation();

  @override
  PostDetailsWrapperBuilder? get detailsWrapperBuilder => null;

  @override
  PostDetailsUIBuilder detailsBuilder(UnifiedPost post) =>
      const PostDetailsUIBuilder();

  @override
  bool supports(BooruPostData data) => data is _NativeData;
}
