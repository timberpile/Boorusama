import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../boorus/danbooru/tags/edit/src/providers/tag_edit_notifier.dart';
import '../../boorus/danbooru/tags/edit/src/tag_edit_page.dart';
import '../configs/config/types.dart';
import '../configs/manage/providers.dart';
import '../posts/details/types.dart';
import '../posts/details_parts/widgets.dart';
import '../posts/listing/types.dart';
import '../posts/rating/types.dart';
import '../settings/routes.dart';
import '../tags/categories/types.dart';
import '../tags/tag/types.dart';
import '../widgets/adaptive_button_row.dart';
import '../widgets/booru_menu_button_row.dart';
import 'local_media_library.dart';
import 'local_media_models.dart';
import 'local_media_providers.dart';
import 'local_media_reference.dart';
import 'local_media_tags.dart';
import 'local_media_thumbnail.dart';

class LocalMediaActions extends ConsumerWidget {
  const LocalMediaActions(this.reference, {super.key});

  final LocalMediaReference reference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref
        .watch(localMediaPresentationProvider(reference))
        .valueOrNull;
    final t = context.t.local_media;
    final scoped = PostActionToolbarScope.maybeOf(context);
    final pager = PostDetailsPageViewScope.of(context);
    return SizedBox(
      width: double.infinity,
      child: BooruMenuButtonRow(
        alignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        buttonWidth: 48,
        invokeAfterClose: true,
        buttons: [
          ButtonData(
            required: true,
            title: context.t.post.action.bookmark,
            icon: const Icon(Icons.bookmark_border),
            widget:
                scoped?.bookmarkButton ??
                BookmarkPostButton(
                  post: media?.item.toPost() ?? localMediaPost(reference),
                  config: BooruConfig.empty.auth,
                ),
          ),
          if (media != null) ...[
            if (media.file != null)
              SimpleButtonData(
                icon: Icons.share,
                title: context.t.post.action.share,
                onPressed: () => unawaited(
                  _withLibrary(
                    context,
                    ref,
                    (library) => shareLocalMedia(context, library, [reference]),
                  ),
                ),
              ),
            SimpleButtonData(
              icon: Icons.edit_outlined,
              title: t.edit,
              placement: ButtonPlacement.menuOnly,
              onPressed: () => unawaited(
                editLocalMedia(
                  context,
                  () => ref.read(localMediaLibraryProvider.future),
                  media.item,
                  ref.read(localMediaTagLookupProvider),
                ),
              ),
            ),
            SimpleButtonData(
              icon: Icons.delete_outline,
              title: t.delete,
              placement: ButtonPlacement.menuOnly,
              onPressed: () => unawaited(_delete(context, ref)),
            ),
          ],
          if (pager.totalPage > 1)
            SimpleButtonData(
              icon: Icons.slideshow,
              title: context.t.post.action.slideshow,
              onPressed: () => unawaited(pager.startSlideshow()),
            ),
          SimpleButtonData(
            icon: Icons.settings,
            title: context.t.settings.settings,
            placement: ButtonPlacement.menuOnly,
            onPressed: () => unawaited(openImageViewerSettingsPage(ref)),
          ),
        ],
      ),
    );
  }

  Future<void> _withLibrary(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(LocalMediaLibrary) action,
  ) async {
    final library = await ref.read(localMediaLibraryProvider.future);
    if (library != null && context.mounted) await action(library);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    await _withLibrary(context, ref, (library) async {
      final deleted = await deleteLocalMedia(context, library, [reference]);
      if (deleted &&
          navigator.mounted &&
          (route?.isCurrent ?? false) &&
          navigator.canPop()) {
        navigator.pop();
      }
    });
  }
}

Future<void> shareLocalMedia(
  BuildContext context,
  LocalMediaLibrary library,
  List<LocalMediaReference> references,
) async {
  try {
    final files = <XFile>[];
    for (final reference in references) {
      final item = library.find(reference);
      final file = await library.resolve(reference);
      if (item == null || file == null) {
        if (context.mounted) {
          Kurumi.showErrorToast(context, context.t.local_media.share_failed);
        }
        return;
      }
      files.add(XFile(file.path, mimeType: item.format.mime));
    }
    if (!context.mounted) return;
    final result = await SharePlus.instance.share(ShareParams(files: files));
    if (result.status != ShareResultStatus.unavailable) return;
  } on Exception {
    // Report platform failures and files that vanished after selection.
  }
  if (context.mounted) {
    Kurumi.showErrorToast(context, context.t.local_media.share_failed);
  }
}

Future<void> editLocalMedia(
  BuildContext context,
  Future<LocalMediaLibrary?> Function() getLibrary,
  LocalMediaItem item,
  Future<List<Tag>> Function(Set<String>) resolveTags,
) async {
  final post = item.toPost();
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ProviderScope(
        overrides: [
          currentReadOnlyBooruConfigAuthProvider.overrideWithValue(
            localMediaTagAuth,
          ),
        ],
        child: PostTagEditEditor(
          params: TagEditParams(
            initialTags: item.tags.map((tag) => tag.name).toSet(),
            initialTagCategories: {
              for (final tag in item.tags) tag.name: tag.category,
            },
            postId: item.id,
            imageAspectRatio: post.aspectRatio ?? 1,
            imageUrl: '',
            placeholderMedia: GridThumbnailMedia(
              url: '',
              aspectRatio: post.aspectRatio,
            ),
            initialRating: item.rating,
            post: post,
          ),
          preview: LocalMediaThumbnail(
            reference: item.reference,
            fit: BoxFit.contain,
            animateGif: true,
          ),
          searchConfig: localMediaTagAuth,
          allowUnrated: true,
          onSubmit: (context, tags, rating) => _saveLocalMediaEdit(
            context,
            getLibrary,
            resolveTags,
            item,
            tags,
            rating,
          ),
        ),
      ),
    ),
  );
}

Future<void> _saveLocalMediaEdit(
  BuildContext context,
  Future<LocalMediaLibrary?> Function() getLibrary,
  Future<List<Tag>> Function(Set<String>) resolveTags,
  LocalMediaItem item,
  Set<String> tags,
  Rating? rating,
) async {
  try {
    final names = {
      for (final tag in tags)
        normalizeLocalMediaTag((name: tag, category: 'general')).name,
    };
    final categories = {for (final tag in item.tags) tag.name: tag.category};
    final added = names.difference(categories.keys.toSet());
    if (added.isNotEmpty) {
      try {
        final resolved = await resolveTags(added)
            .timeout(const Duration(seconds: 3), onTimeout: () => []);
        for (final tag in resolved) {
          if (tag.category != TagCategory.unknown()) {
            categories[tag.name] = tag.category.name;
          }
        }
      } on Exception {
        // Manual tags remain editable offline.
      }
    }
    if (!context.mounted) return;
    final library = await getLibrary();
    if (!context.mounted) return;
    if (library == null) {
      Kurumi.showErrorToast(context, context.t.local_media.operation_failed);
      return;
    }
    await library.edit(
      item.reference,
      tags: [
        for (final name in names)
          (name: name, category: categories[name] ?? 'general'),
      ],
      rating: rating ?? item.rating,
    );
    if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.of(context).pop();
    }
  } on Exception {
    if (context.mounted) {
      Kurumi.showErrorToast(context, context.t.local_media.operation_failed);
    }
  }
}

Future<bool> deleteLocalMedia(
  BuildContext context,
  LocalMediaLibrary library,
  List<LocalMediaReference> references,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => KurumiDialog(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t.local_media.confirm_delete(n: references.length)),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.t.generic.action.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.t.local_media.delete),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    for (final reference in references) {
      await library.delete(reference);
    }
    return true;
  } on Exception {
    if (context.mounted) {
      Kurumi.showErrorToast(context, context.t.local_media.operation_failed);
    }
    return false;
  }
}
