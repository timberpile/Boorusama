// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import '../../../posts/listing/providers.dart';
import '../../../router.dart';
import '../data/bookmark_convert.dart';
import '../providers/bookmark_provider.dart';
import '../types/bookmark_target.dart';
import '../types/bookmark_view.dart';

Future<void> goToBookmarkPage(
  WidgetRef ref,
) {
  return ref.router.push(
    Uri(
      path: '/bookmarks',
    ).toString(),
  );
}

Future<void> goToBookmarkGroupPage(
  WidgetRef ref,
  BookmarkView view, {
  required String title,
}) async {
  if (view.kind != BookmarkViewKind.all) {
    final activated = await ref
        .read(bookmarkProvider.notifier)
        .setActiveTarget(
          view.kind == BookmarkViewKind.ungrouped
              ? const BookmarkTarget.ungrouped()
              : BookmarkTarget.group(view.groupId!),
        );
    if (!activated) {
      if (ref.context.mounted) {
        Kurumi.showErrorToast(
          ref.context,
          ref.context.t.bookmark.groups.operation_failed,
        );
      }
      return;
    }
  }
  await ref.router.push(
    Uri(
      path: '/bookmarks/group',
      queryParameters: {
        'kind': view.kind.name,
        'id': ?view.groupId,
        'title': title,
      },
    ).toString(),
  );
}

Future<void> goToBookmarkDetailsPage(
  WidgetRef ref,
  int index, {
  required String initialThumbnailUrl,
  required PostGridController<BookmarkPost> controller,
}) {
  return ref.router.push(
    Uri(
      path: '/bookmarks/details',
      queryParameters: {
        'index': index.toString(),
      },
    ).toString(),
    extra: {
      'controller': controller,
      'initialThumbnailUrl': initialThumbnailUrl,
    },
  );
}
