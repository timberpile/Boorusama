// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../core/posts/post/types.dart';

final class GelbooruV2PostData extends Equatable implements BooruPostData {
  const GelbooruV2PostData({
    required this.hasNotes,
    this.isVideoPreview = false,
  });

  final bool hasNotes;
  final bool isVideoPreview;

  @override
  String get typeKey => 'gelbooru_v2';

  @override
  int get schemaVersion => 2;

  @override
  List<Object?> get props => [hasNotes, isVideoPreview];
}

extension GelbooruV2PostDataX on Post {
  bool get hasNotes => switch (booruData) {
    GelbooruV2PostData(:final hasNotes) => hasNotes,
    _ => false,
  };

  bool get isVideoPreview => switch (booruData) {
    GelbooruV2PostData(:final isVideoPreview) => isVideoPreview,
    _ => false,
  };
}
