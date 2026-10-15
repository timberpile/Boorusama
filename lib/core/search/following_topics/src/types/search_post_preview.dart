// Package imports:
import 'package:equatable/equatable.dart';

class SearchPostPreview extends Equatable {
  const SearchPostPreview({
    required this.postId,
    required this.postCreatedAt,
    required this.thumbnailUrl,
    required this.sampleUrl,
    required this.discoveredAt,
  });

  final int postId;
  final DateTime? postCreatedAt;
  final String thumbnailUrl;
  final String? sampleUrl;
  final DateTime discoveredAt;

  @override
  List<Object?> get props => [
    postId,
    postCreatedAt,
    thumbnailUrl,
    sampleUrl,
    discoveredAt,
  ];
}

class RecentSearchPostIdentity extends Equatable {
  const RecentSearchPostIdentity({
    required this.postId,
    required this.postCreatedAt,
  });

  final int postId;
  final DateTime postCreatedAt;

  @override
  List<Object?> get props => [postId, postCreatedAt];
}
