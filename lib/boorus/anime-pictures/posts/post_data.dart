// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../core/posts/post/types.dart';

final class AnimePicturesPostData extends Equatable implements BooruPostData {
  const AnimePicturesPostData({
    required this.tagsCount,
    required this.statusValue,
    required this.statusType,
  });

  final int tagsCount;
  final int? statusValue;
  final int? statusType;

  @override
  String get typeKey => 'anime_pictures';

  @override
  int get schemaVersion => 1;

  @override
  List<Object?> get props => [tagsCount, statusValue, statusType];
}
