// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
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
    if (data.seriesTitle case final value?) 'seriesTitle': value,
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
      illustId: json['illustId'] as int,
      pageIndex: json['pageIndex'] as int,
      pageCount: json['pageCount'] as int,
      userId: json['userId'] as int,
      userName: json['userName'] as String,
      userAccount: json['userAccount'] as String,
      illustType: illustType,
      totalBookmarks: json['totalBookmarks'] as int,
      totalView: json['totalView'] as int,
      aiType: json['aiType'] as int,
      seriesTitle: json['seriesTitle'] as String?,
      isUgoira: json['isUgoira'] as bool,
      isRestricted: json['isRestricted'] as bool,
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
