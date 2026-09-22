// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../core/posts/post/types.dart';
import 'types.dart';

final class PhilomenaPostData extends Equatable implements BooruPostData {
  const PhilomenaPostData({
    required this.description,
    required this.commentCount,
    required this.favCount,
    required this.upvotes,
    required this.representation,
  });

  final String description;
  final int commentCount;
  final int favCount;
  final int upvotes;
  final PhilomenaRepresentation representation;

  @override
  String get typeKey => 'philomena';

  @override
  int get schemaVersion => 1;

  @override
  List<Object?> get props => [
    description,
    commentCount,
    favCount,
    upvotes,
    representation,
  ];
}
