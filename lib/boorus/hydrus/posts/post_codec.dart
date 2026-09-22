// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class HydrusPostCodec implements BooruPostDataCodec<HydrusPostData> {
  const HydrusPostCodec();

  @override
  String get typeKey => 'hydrus';

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) => data is HydrusPostData;

  @override
  Map<String, Object?> encode(HydrusPostData data) => {
    if (data.ownFavorite case final value?) 'ownFavorite': value,
  };

  @override
  HydrusPostData decode(
    Map<String, Object?> json, {
    required int version,
  }) {
    if (version != 1) {
      throw const FormatException('Unsupported Hydrus post data');
    }
    return HydrusPostData(ownFavorite: json['ownFavorite'] as bool?);
  }
}

UnifiedPost hydrusPostToUnified(HydrusPost post, PostOrigin origin) =>
    UnifiedPost(
      origin: origin,
      core: PostCoreData.fromPost(post),
      booruData: HydrusPostData(ownFavorite: post.ownFavorite),
    );
