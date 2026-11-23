import 'package:equatable/equatable.dart';

import '../posts/post/types.dart';
import 'content_reference.dart';
import 'groups/group_summary.dart';

sealed class ContentEntry extends Equatable {
  const ContentEntry();
  ContentReference get reference;
}

final class PostContentEntry extends ContentEntry {
  PostContentEntry({
    required this.reference,
    required this.post,
    ContentKeyCodec? keyCodec,
  }) {
    final codec = keyCodec ?? BooruContentKeyCodec(reference.engine);
    if (reference.kind != ContentKind.post ||
        reference.engine != post.origin.booruType ||
        reference.siteNamespace != post.origin.sourceHost ||
        codec.engine != reference.engine ||
        codec.keyForPost(post) != reference.sourceKey) {
      throw const FormatException('Incompatible hydrated Post');
    }
  }
  @override
  final ContentReference reference;
  final Post post;
  @override
  List<Object?> get props => [reference, post];
}

final class GroupContentEntry extends ContentEntry {
  const GroupContentEntry({required this.summary});
  final ContentGroupSummary summary;
  @override
  ContentReference get reference => summary.reference;
  @override
  List<Object?> get props => [summary];
}
