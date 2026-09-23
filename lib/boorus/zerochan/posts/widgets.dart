// Project imports:
import '../../../core/posts/details_parts/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/posts/post/types.dart';

final kZerochanPostDetailsUIBuilder = PostDetailsUIBuilder(
  preview: {
    DetailsPart.toolbar: (context) =>
        const DefaultInheritedPostActionToolbar<Post>(),
  },
  full: {
    DetailsPart.toolbar: (context) =>
        const DefaultInheritedPostActionToolbar<Post>(),
    DetailsPart.source: (context) =>
        const DefaultInheritedSourceSection<Post>(),
    DetailsPart.tags: (context) => const DefaultInheritedTagsTile<Post>(),
    DetailsPart.fileDetails: (context) =>
        const DefaultInheritedFileDetailsSection<Post>(),
  },
);
