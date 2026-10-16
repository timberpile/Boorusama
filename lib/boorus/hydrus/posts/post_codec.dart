// Project imports:
import '../../../core/posts/post/types.dart';
import 'types.dart';

final class HydrusPostCodec implements BooruPostDataCodec<HydrusPostData> {
  const HydrusPostCodec();

  @override
  String get typeKey => 'hydrus';

  @override
  int get currentVersion => 2;

  @override
  bool supports(BooruPostData data) => data is HydrusPostData;

  @override
  Map<String, Object?> encode(HydrusPostData data) => {
    'ownFavorite': ?data.ownFavorite,
    'sourceUrls': data.sourceUrls,
  };

  @override
  HydrusPostData decode(
    Map<String, Object?> json, {
    required int version,
  }) {
    if (version < 1 || version > currentVersion) {
      throw const FormatException('Unsupported Hydrus post data');
    }
    return HydrusPostData(
      ownFavorite: json['ownFavorite'] as bool?,
      sourceUrls: version >= 2
          ? (json['sourceUrls'] as List?)?.whereType<String>().toList() ??
                const []
          : const [],
    );
  }
}

Post hydrusPostFromRecord(HydrusPostRecord post, PostOrigin origin) => Post(
  origin: origin,
  core: PostCoreData.fromPost(post),
  booruData: HydrusPostData(
    ownFavorite: post.ownFavorite,
    sourceUrls: post.sourceUrls,
  ),
);
