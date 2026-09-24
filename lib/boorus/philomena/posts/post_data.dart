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

extension PhilomenaPostDataX on Post {
  PhilomenaPostData? get philomenaData => switch (booruData) {
    final PhilomenaPostData data => data,
    _ => null,
  };

  String get description => philomenaData?.description ?? '';
  int get commentCount => philomenaData?.commentCount ?? 0;
  int get favCount => philomenaData?.favCount ?? 0;
  int get upvotes => philomenaData?.upvotes ?? 0;
  PhilomenaRepresentation get representation =>
      philomenaData?.representation ??
      PhilomenaRepresentation(
        full: originalImageUrl,
        large: sampleImageUrl,
        medium: sampleImageUrl,
        small: thumbnailImageUrl,
        tall: thumbnailImageUrl,
        thumb: thumbnailImageUrl,
        thumbSmall: thumbnailImageUrl,
        thumbTiny: thumbnailImageUrl,
      );
}
