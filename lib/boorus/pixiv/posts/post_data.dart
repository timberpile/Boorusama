// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../core/posts/post/types.dart';
import 'types.dart';

final class PixivPostData extends Equatable implements BooruPostData {
  const PixivPostData({
    required this.illustId,
    required this.pageIndex,
    required this.pageCount,
    required this.userId,
    required this.userName,
    required this.userAccount,
    required this.illustType,
    required this.totalBookmarks,
    required this.totalView,
    required this.aiType,
    required this.seriesTitle,
    required this.isUgoira,
    required this.isRestricted,
  });

  final int illustId;
  final int pageIndex;
  final int pageCount;
  final int userId;
  final String userName;
  final String userAccount;
  final PixivIllustType illustType;
  final int totalBookmarks;
  final int totalView;
  final int aiType;
  final String? seriesTitle;
  final bool isUgoira;
  final bool isRestricted;

  @override
  String get typeKey => 'pixiv';

  @override
  int get schemaVersion => 1;

  @override
  List<Object?> get props => [
    illustId,
    pageIndex,
    pageCount,
    userId,
    userName,
    userAccount,
    illustType,
    totalBookmarks,
    totalView,
    aiType,
    seriesTitle,
    isUgoira,
    isRestricted,
  ];
}

extension PixivPostDataX on Post {
  PixivPostData? get pixivData => switch (booruData) {
    final PixivPostData data => data,
    _ => null,
  };

  int get illustId => pixivData?.illustId ?? id;
  int get pageIndex => pixivData?.pageIndex ?? 0;
  int get pageCount => pixivData?.pageCount ?? 1;
  int get userId => pixivData?.userId ?? 0;
  String get userName => pixivData?.userName ?? '';
  String get userAccount => pixivData?.userAccount ?? '';
  PixivIllustType get illustType =>
      pixivData?.illustType ?? PixivIllustType.unknown;
  int get totalBookmarks => pixivData?.totalBookmarks ?? 0;
  int get totalView => pixivData?.totalView ?? 0;
  int get aiType => pixivData?.aiType ?? 0;
  String? get seriesTitle => pixivData?.seriesTitle;
  bool get isUgoira => pixivData?.isUgoira ?? false;
  bool get isRestricted => pixivData?.isRestricted ?? false;
  bool get hasMultiplePages => pageCount > 1;
}
