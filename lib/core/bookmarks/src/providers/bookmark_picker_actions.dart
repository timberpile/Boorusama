import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../configs/manage/providers.dart';
import '../../../configs/config/types.dart';
import '../types/bookmark_picker_request.dart';
import '../services/bookmark_library_service.dart';
import '../types/bookmark_target.dart';
import '../types/pool_bookmark.dart';
import 'bookmark_provider.dart';
import 'pool_bookmark_provider.dart';
import 'related_bookmark_provider.dart';

/// Keep the shared draft alive while a picker or its creation dialog owns it.
/// Preparation never gates opening; a complete draft is needed only for a write.
void watchBookmarkPickerDraft(WidgetRef ref, BookmarkPickerRequest request) {
  final identity = request.collectionIdentity;
  if (identity != null &&
      (ref
              .watch(bookmarkProvider)
              .valueOrNull
              ?.pools
              .any((p) => p.identity == identity) ??
          false)) {
    return;
  }
  switch (request) {
    case RemotePoolBookmarkPickerRequest(:final source, :final pool):
      ref.watch(poolBookmarkDraftProvider((source, pool)));
    case RelatedBookmarkPickerRequest(:final source, :final family):
      ref.watch(relatedBookmarkDraftProvider((source, family)));
    default:
      break;
  }
}

/// One operation owner per picker, transferred explicitly to group creation.
/// The presenter supplies ownership, including the anchor's closing animation.
class BookmarkPickerActions {
  BookmarkPickerActions({
    required this.container,
    required BookmarkPickerRequest request,
    required this.isActive,
  }) : request = switch (request) {
         PostBookmarkPickerRequest(:final config, :final post, source: null) =>
           PostBookmarkPickerRequest(
             config: config,
             post: post,
             source: container
                 .read(booruConfigProvider)
                 .where((source) => source.auth == config)
                 .firstOrNull,
           ),
         _ => request,
       };
  final ProviderContainer container;
  final BookmarkPickerRequest request;
  final bool Function() isActive;
  var _pending = false;
  var _disposed = false;

  bool get pending => _pending;

  void dispose() => _disposed = true;

  void _checkOwnership() {
    if (_disposed || !isActive()) throw StateError('Bookmark picker dismissed');
    if (request.source case final source?) {
      if (!container.read(booruConfigProvider).contains(source)) {
        throw StateError('Bookmark picker source changed');
      }
    }
  }

  Future<CollectionBookmark?> _resolveCollection() async {
    _checkOwnership();
    final identity = request.collectionIdentity;
    final saved = container
        .read(bookmarkProvider)
        .valueOrNull
        ?.pools
        .where((p) => p.identity == identity)
        .firstOrNull;
    final draft =
        saved ??
        switch (request) {
          StoredBookmarkPickerRequest(:final collection) => collection,
          RemotePoolBookmarkPickerRequest(:final source, :final pool) =>
            await container.read(
              poolBookmarkDraftProvider((source, pool)).future,
            ),
          RelatedBookmarkPickerRequest(:final source, :final family) =>
            await container.read(
              relatedBookmarkDraftProvider((source, family)).future,
            ),
          PostBookmarkPickerRequest() => null,
        };
    _checkOwnership();
    return draft;
  }

  Future<BookmarkToggleOutcome?> toggle(
    String groupId, {
    required void Function(BookmarkGroupRemovalResult) onRemoved,
  }) async {
    if (_pending) return null;
    _pending = true;
    try {
      final collection = await _resolveCollection();
      _checkOwnership();
      final notifier = container.read(bookmarkProvider.notifier);
      return collection != null
          ? await notifier.togglePoolTarget(
              collection,
              groupId: groupId,
              onRemoved: onRemoved,
            )
          : await notifier.togglePostTarget(
              request.config,
              (request as PostBookmarkPickerRequest).post,
              target: BookmarkTarget.group(groupId),
              onRemoved: onRemoved,
            );
    } finally {
      _pending = false;
    }
  }

  Future<void> createGroup(
    String name,
    String? folderId, {
    required void Function() beforeCommit,
  }) async {
    if (_pending) return;
    _pending = true;
    try {
      final collection = await _resolveCollection();
      _checkOwnership();
      beforeCommit();
      await container
          .read(bookmarkProvider.notifier)
          .createGroupWithPosts(
            name,
            request.config,
            switch (request) {
              PostBookmarkPickerRequest(:final post) => [post],
              _ => [],
            },
            folderId: folderId,
            pools: [?collection],
          );
    } finally {
      _pending = false;
    }
  }
}
