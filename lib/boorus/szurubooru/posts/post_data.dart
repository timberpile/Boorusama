// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../core/posts/post/types.dart';
import '../../../core/tags/tag/types.dart';
import '../pools/types.dart';

final class SzurubooruPostData extends Equatable implements BooruPostData {
  const SzurubooruPostData({
    required this.ownFavorite,
    required this.favoriteCount,
    required this.commentCount,
    required this.tagDetails,
    required this.status,
    required this.pools,
  });

  final bool ownFavorite;
  final int favoriteCount;
  final int commentCount;
  final List<Tag> tagDetails;
  final String? status;
  final List<SzurubooruPool> pools;

  @override
  String get typeKey => 'szurubooru';

  @override
  int get schemaVersion => 1;

  @override
  List<Object?> get props => [
    ownFavorite,
    favoriteCount,
    commentCount,
    tagDetails,
    status,
    pools,
  ];
}

extension SzurubooruPostDataX on Post {
  SzurubooruPostData? get szurubooruData => switch (booruData) {
    final SzurubooruPostData data => data,
    _ => null,
  };

  bool get ownFavorite => szurubooruData?.ownFavorite ?? false;
  int get favoriteCount => szurubooruData?.favoriteCount ?? 0;
  int get commentCount => szurubooruData?.commentCount ?? 0;
  List<Tag> get tagDetails => szurubooruData?.tagDetails ?? const [];
  List<SzurubooruPool> get pools => szurubooruData?.pools ?? const [];
}
