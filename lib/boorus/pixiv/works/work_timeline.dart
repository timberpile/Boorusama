import 'package:kurumi/material.dart';

import '../../../core/posts/details/src/types/viewer_entry.dart';
import '../../../core/posts/details/src/widgets/group_media_timeline.dart';
import '../favorites/favorite_control.dart';
import 'work_mapper.dart';

class PixivWorkTimeline extends StatelessWidget {
  const PixivWorkTimeline({required this.entry, super.key});

  final GroupViewerEntry entry;

  @override
  Widget build(BuildContext context) => GroupMediaTimeline(
    entry: entry,
    favorite: (state) => switch (pixivWorkIllustId(entry.contentReference)) {
      final id? when !state.failed && state.access != null =>
        PixivFavoriteControl(
          key: ValueKey((state.access!.key, id)),
          access: state.access,
          illustId: id,
        ),
      _ => null,
    },
  );
}
