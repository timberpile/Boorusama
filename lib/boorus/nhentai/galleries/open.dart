import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/types.dart';
import '../../../core/posts/details/routes.dart';
import '../../../core/posts/details/src/types/viewer_entry.dart';
import '../../../core/posts/post/types.dart';

void openNhentaiGalleries(
  WidgetRef ref,
  ContentAccessContext access,
  List<ContentGroupSummary> galleries,
  int index,
) {
  final config = access.config!;
  final binding = access.key.profileId == null
      ? ViewerSourceBinding.publicRead(
          PostOrigin.fromSource(
            booruType: access.key.engine,
            booruId: access.key.engine.id,
            source: config.url,
          ),
        )
      : ViewerSourceBinding(config);
  goToPostDetailsPageCore<Post>(
    ref: ref,
    posts: const [],
    entries: [
      for (final summary in galleries)
        GroupViewerEntry(
          summary: summary,
          occurrenceId: Object(),
          source: binding,
        ),
    ],
    initialIndex: index,
    hero: false,
    initialThumbnailUrl: galleries[index].cover?.thumbnail.toString(),
    config: config,
  );
}
