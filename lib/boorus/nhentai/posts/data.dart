import 'package:booru_clients/nhentai.dart';
import 'package:equatable/equatable.dart';

import '../../../core/posts/post/types.dart';

/// The source locator stays independent from the numeric compatibility bridge.
final class NhentaiPostData extends Equatable
    implements BooruPostData, StableBookmarkPostKeyData, SitePostIdData {
  NhentaiPostData({required int galleryId, required int pageNumber})
    : identity = NhentaiPageIdentity(
        galleryId: galleryId,
        pageNumber: pageNumber,
      );
  final NhentaiPageIdentity identity;
  int get galleryId => identity.galleryId;
  int get pageNumber => identity.pageNumber;
  @override
  String get stableBookmarkPostKey => identity.sourceKey;
  @override
  String get sitePostId => '${galleryId}_p$pageNumber';
  @override
  String get typeKey => 'nhentai';
  @override
  int get schemaVersion => 1;
  @override
  List<Object?> get props => [identity];
}

final class NhentaiPostCodec implements BooruPostDataCodec<NhentaiPostData> {
  const NhentaiPostCodec();
  @override
  String get typeKey => 'nhentai';
  @override
  int get currentVersion => 1;
  @override
  bool supports(BooruPostData data) => data is NhentaiPostData;
  @override
  Map<String, Object?> encode(NhentaiPostData data) => {
    'galleryId': data.galleryId,
    'pageNumber': data.pageNumber,
  };
  @override
  NhentaiPostData decode(Map<String, Object?> json, {required int version}) {
    if (version != currentVersion ||
        json['galleryId'] is! int ||
        json['pageNumber'] is! int) {
      throw const FormatException('Invalid nhentai Page data');
    }
    return NhentaiPostData(
      galleryId: json['galleryId']! as int,
      pageNumber: json['pageNumber']! as int,
    );
  }
}
