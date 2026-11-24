import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../boorus/booru/types.dart';
import '../../../content/content_access_provider.dart';
import '../../../content/groups/group_source_provider.dart';
import '../../../content/types.dart';
import '../../../http/client/coordination.dart';
import '../services/bookmark_presentation_covers.dart';
import '../types/content_group_bookmark.dart';
import '../types/pool_bookmark_cover.dart';
import 'bookmark_provider.dart';
import 'bookmark_read_access.dart';
import 'pool_bookmark_provider.dart';

bool needsNativeWorkCover(ContentGroupBookmark bookmark) =>
    bookmark.reference.engine == BooruType.pixiv &&
    bookmark.summary.cover?.visibility?.tagCoverage !=
        MetadataCoverage.complete;

final nativeWorkSavedCoverProvider = Provider.autoDispose
    .family<GroupCover?, ContentGroupBookmark>((ref, bookmark) {
      if (!needsNativeWorkCover(bookmark)) return bookmark.summary.cover;
      final library = ref.watch(bookmarkProvider).asData?.value;
      final key = library == null
          ? null
          : nativeWorkPresentationCoverKey(library, bookmark);
      final choice = key == null
          ? null
          : ref.watch(bookmarkPresentationCoversProvider).selected(key);
      return choice == null
          ? bookmark.summary.cover
          : GroupCover(
              thumbnail: Uri.parse(choice.thumbnail),
              sample: Uri.parse(choice.sample),
              visibility: choice.visibility,
              aspectRatios: choice.aspectRatios,
            );
    });

final missingNativeWorkCoverProvider = FutureProvider.autoDispose
    .family<GroupCover?, (ContentGroupBookmark, ContentAccessKey)>(
      (
        ref,
        request,
      ) => Future.sync(() {
        final (bookmark, reader) = request;
        final existing = ref.watch(nativeWorkSavedCoverProvider(bookmark));
        if (!needsNativeWorkCover(bookmark) ||
            existing?.visibility?.tagCoverage == MetadataCoverage.complete) {
          return existing;
        }

        final target = BookmarkReaderRequest.reference(bookmark.reference);
        final access = ref.watch(bookmarkReadAccessProvider(target));
        final config = access?.config;
        if (config == null || access == null || access.key != reader) {
          return null;
        }
        final token = CancelToken();
        ref.onDispose(() => token.cancel('Bookmark cover owner gone'));
        final library = ref.read(bookmarkProvider).asData?.value;
        if (library == null || library.byId[bookmark.id] != bookmark) {
          return null;
        }
        final choiceKey = nativeWorkPresentationCoverKey(library, bookmark);
        if (choiceKey == null &&
            !library.localBookmarkIds.contains(bookmark.id)) {
          return null;
        }
        final source = ref
            .watch(contentGroupSourceStateProvider(reader))
            .asData
            ?.value;
        if (source == null) return null;
        bool current() {
          if (token.isCancelled) return false;
          final latest = ref.read(bookmarkProvider).asData?.value;
          return latest != null &&
              latest.byId[bookmark.id] == bookmark &&
              latest.groups.any(
                (group) => group.bookmarkIds.contains(bookmark.id),
              ) &&
              nativeWorkPresentationCoverKey(latest, bookmark) == choiceKey &&
              (ref
                      .read(bookmarkReadAccessProvider(target))
                      ?.hasSameAuthorization(access) ??
                  false) &&
              (ref
                      .read(contentAccessContextProvider(reader))
                      ?.hasSameAuthorization(access) ??
                  false);
        }

        return ref.read(poolCoverBackfillQueueProvider).run<GroupCover?>(
          (reader, bookmark, choiceKey),
          () async {
            if (!current()) return null;
            final summary = await runWithApiRequestContext(
              ApiRequestContext(
                requestClass: ApiRequestClass.preload,
                cancelToken: token,
                canStart: current,
                canAdmit: current,
                allowCooldownRetry: false,
              ),
              () => runGroupRead(
                source,
                () => source.loadSummary(bookmark.reference),
                token: token,
                current: current,
              ),
            );
            final cover = summary.cover;
            if (!current() ||
                summary.reference != bookmark.reference ||
                cover == null ||
                cover.visibility?.tagCoverage != MetadataCoverage.complete) {
              return null;
            }
            if (choiceKey != null) {
              await ref
                  .read(bookmarkPresentationCoversProvider)
                  .remember(
                    choiceKey,
                    PoolBookmarkCover(
                      thumbnail: cover.thumbnail.toString(),
                      sample: (cover.sample ?? cover.thumbnail).toString(),
                      original: (cover.sample ?? cover.thumbnail).toString(),
                      variants: const {},
                      visibility: cover.visibility,
                      aspectRatios: cover.aspectRatios,
                    ),
                    current: current,
                  );
            } else {
              await ref
                  .read(bookmarkProvider.notifier)
                  .fillMissingNativeWorkCover(
                    bookmark,
                    cover,
                    canCommit: current,
                  );
            }
            return token.isCancelled ? null : cover;
          },
        );
      }),
    );
