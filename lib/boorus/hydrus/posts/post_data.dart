// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../core/posts/post/types.dart';

final class HydrusPostData extends Equatable
    implements BooruPostData, PostSourceUrlsData {
  const HydrusPostData({required this.ownFavorite, this.sourceUrls = const []});

  final bool? ownFavorite;
  @override
  final List<String> sourceUrls;

  @override
  String get typeKey => 'hydrus';

  @override
  int get schemaVersion => 2;

  @override
  List<Object?> get props => [ownFavorite, sourceUrls];
}

extension HydrusPostDataX on Post {
  bool? get ownFavorite => switch (booruData) {
    HydrusPostData(:final ownFavorite) => ownFavorite,
    _ => null,
  };
}
