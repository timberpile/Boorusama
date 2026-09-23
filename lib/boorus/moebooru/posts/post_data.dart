// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../core/posts/post/types.dart';

final class MoebooruPostData extends Equatable implements BooruPostData {
  const MoebooruPostData({required this.largeImageUrl});

  final String largeImageUrl;

  @override
  String get typeKey => 'moebooru';

  @override
  int get schemaVersion => 1;

  @override
  List<Object?> get props => [largeImageUrl];
}

extension MoebooruPostDataX on Post {
  String get largeImageUrl => switch (booruData) {
    MoebooruPostData(:final largeImageUrl) => largeImageUrl,
    _ => '',
  };
}
