// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../core/posts/post/types.dart';
import '../../../core/tags/tag/types.dart';

final class SankakuPostData extends Equatable implements BooruPostData {
  const SankakuPostData({
    required this.sankakuId,
    required this.isFavorited,
    required this.favoriteCount,
    required this.artistDetailsTags,
    required this.characterDetailsTags,
    required this.copyrightDetailsTags,
    required this.generalDetailsTags,
    required this.metaDetailsTags,
  });

  final SankakuPostIdData? sankakuId;
  final bool isFavorited;
  final int favoriteCount;
  final List<Tag> artistDetailsTags;
  final List<Tag> characterDetailsTags;
  final List<Tag> copyrightDetailsTags;
  final List<Tag> generalDetailsTags;
  final List<Tag> metaDetailsTags;

  @override
  String get typeKey => 'sankaku';

  @override
  int get schemaVersion => 1;

  @override
  List<Object?> get props => [
    sankakuId,
    isFavorited,
    favoriteCount,
    artistDetailsTags,
    characterDetailsTags,
    copyrightDetailsTags,
    generalDetailsTags,
    metaDetailsTags,
  ];
}

final class SankakuPostIdData extends Equatable {
  const SankakuPostIdData({required this.value, required this.isNumeric});

  final String value;
  final bool isNumeric;

  @override
  List<Object?> get props => [value, isNumeric];
}
