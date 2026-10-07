// Project imports:
import '../../../core/posts/post/types.dart';
import 'types.dart';

final class PixivPostCodec implements BooruPostDataCodec<PixivPostData> {
  const PixivPostCodec();

  @override
  String get typeKey => 'pixiv';

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) => data is PixivPostData;

  @override
  Map<String, Object?> encode(PixivPostData data) => {
    'illustId': data.illustId,
    'pageIndex': data.pageIndex,
    'pageCount': data.pageCount,
    'userId': data.userId,
    'userName': data.userName,
    'userAccount': data.userAccount,
    'illustType': data.illustType.name,
    'totalBookmarks': data.totalBookmarks,
    'totalView': data.totalView,
    'aiType': data.aiType,
    'seriesTitle': ?data.seriesTitle,
    'isUgoira': data.isUgoira,
    'isRestricted': data.isRestricted,
  };

  @override
  PixivPostData decode(
    Map<String, Object?> json, {
    required int version,
  }) {
    if (version != 1) {
      throw const FormatException('Unsupported Pixiv post data');
    }
    final illustType = PixivIllustType.parse(json['illustType'] as String?);
    if (illustType == PixivIllustType.unknown) {
      throw const FormatException('Invalid Pixiv illustration type');
    }
    return PixivPostData(
      illustId: _required<int>(json['illustId'], 'illustId'),
      pageIndex: _required<int>(json['pageIndex'], 'pageIndex'),
      pageCount: _required<int>(json['pageCount'], 'pageCount'),
      userId: _required<int>(json['userId'], 'userId'),
      userName: _required<String>(json['userName'], 'userName'),
      userAccount: _required<String>(json['userAccount'], 'userAccount'),
      illustType: illustType,
      totalBookmarks: _required<int>(json['totalBookmarks'], 'totalBookmarks'),
      totalView: _required<int>(json['totalView'], 'totalView'),
      aiType: _required<int>(json['aiType'], 'aiType'),
      seriesTitle: json['seriesTitle'] as String?,
      isUgoira: _required<bool>(json['isUgoira'], 'isUgoira'),
      isRestricted: _required<bool>(json['isRestricted'], 'isRestricted'),
    );
  }
}

Post pixivPostFromRecord(PixivPostRecord post, PostOrigin origin) => Post(
  origin: origin,
  core: PostCoreData.fromPost(post),
  booruData: PixivPostData(
    illustId: post.illustId,
    pageIndex: post.pageIndex,
    pageCount: post.pageCount,
    userId: post.userId,
    userName: post.userName,
    userAccount: post.userAccount,
    illustType: post.illustType,
    totalBookmarks: post.totalBookmarks,
    totalView: post.totalView,
    aiType: post.aiType,
    seriesTitle: post.seriesTitle,
    isUgoira: post.isUgoira,
    isRestricted: post.isRestricted,
  ),
);

T _required<T>(Object? value, String field) => switch (value) {
  final T value => value,
  _ => throw FormatException('Invalid Pixiv $field'),
};
