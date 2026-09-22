// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../core/posts/post/types.dart';

final class HydrusPostData extends Equatable implements BooruPostData {
  const HydrusPostData({required this.ownFavorite});

  final bool? ownFavorite;

  @override
  String get typeKey => 'hydrus';

  @override
  int get schemaVersion => 1;

  @override
  List<Object?> get props => [ownFavorite];
}
