// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class PhilomenaPostCodec
    implements BooruPostDataCodec<PhilomenaPostData> {
  const PhilomenaPostCodec();

  @override
  String get typeKey => 'philomena';

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) => data is PhilomenaPostData;

  @override
  Map<String, Object?> encode(PhilomenaPostData data) => {
    'description': data.description,
    'commentCount': data.commentCount,
    'favCount': data.favCount,
    'upvotes': data.upvotes,
    'representation': {
      'full': data.representation.full,
      'large': data.representation.large,
      'medium': data.representation.medium,
      'small': data.representation.small,
      'tall': data.representation.tall,
      'thumb': data.representation.thumb,
      'thumbSmall': data.representation.thumbSmall,
      'thumbTiny': data.representation.thumbTiny,
    },
  };

  @override
  PhilomenaPostData decode(
    Map<String, Object?> json, {
    required int version,
  }) {
    if (version != 1) {
      throw const FormatException('Unsupported Philomena post data');
    }
    final representation = json['representation'];
    if (representation is! Map<String, Object?>) {
      throw const FormatException('Invalid Philomena representation');
    }
    return PhilomenaPostData(
      description: json['description'] as String,
      commentCount: json['commentCount'] as int,
      favCount: json['favCount'] as int,
      upvotes: json['upvotes'] as int,
      representation: PhilomenaRepresentation(
        full: representation['full'] as String,
        large: representation['large'] as String,
        medium: representation['medium'] as String,
        small: representation['small'] as String,
        tall: representation['tall'] as String,
        thumb: representation['thumb'] as String,
        thumbSmall: representation['thumbSmall'] as String,
        thumbTiny: representation['thumbTiny'] as String,
      ),
    );
  }
}

UnifiedPost philomenaPostToUnified(PhilomenaPost post, PostOrigin origin) =>
    UnifiedPost(
      origin: origin,
      core: PostCoreData.fromPost(post),
      booruData: PhilomenaPostData(
        description: post.description,
        commentCount: post.commentCount,
        favCount: post.favCount,
        upvotes: post.upvotes,
        representation: post.representation,
      ),
    );
