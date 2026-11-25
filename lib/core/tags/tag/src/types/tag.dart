// Dart imports:
import 'dart:async';

// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../../../posts/post/types.dart';
import 'tag_value.dart';

export 'tag_value.dart';

typedef TagFetcher = FutureOr<List<Tag>> Function(
  Post post,
  ExtractOptions options,
);

typedef TagFetcherBatch = FutureOr<List<Tag>> Function(
  List<Post> posts,
  ExtractOptions options,
);

class ExtractOptions {
  const ExtractOptions({
    this.fetchTagCount = false,
    this.cancelToken,
  });

  final bool fetchTagCount;
  final CancelToken? cancelToken;
}
