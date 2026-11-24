import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../../../content/groups/group_source_provider.dart';
import '../../../../content/groups/prepared_group_reads.dart';
import '../../../../content/types.dart';
import '../../../../errors/types.dart';
import '../../../../http/client/coordination.dart';
import '../../../../settings/providers.dart';
import '../../../../bookmarks/providers.dart';
import '../../../../bookmarks/src/types/content_group_bookmark.dart' as native;
import '../../../../bookmarks/src/types/legacy_group_bookmark.dart' as legacy;
import '../../../related/related_posts_order_value.dart';
import '../types/viewer_entry.dart';

typedef PreparedViewerKey = ({
  ContentAccessKey access,
  PreparedGroupPageKey page,
  bool foreground,
});
final preparedViewerDetailsProvider = FutureProvider.autoDispose
    .family<ContentGroupDetails, PreparedViewerKey>((ref, key) {
      final shared = ref.watch(preparedGroupReadsProvider(key.access));
      if (shared == null) throw RequestCancelledError();
      return _preparePhase(
        ref,
        key,
        () => shared.details(key.page.reference, key.page.revision),
      );
    }, dependencies: [contentGroupSourceProvider, preparedGroupReadsProvider]);

final preparedViewerGroupProvider = FutureProvider.autoDispose
    .family<GroupMemberBatch, PreparedViewerKey>(
      (ref, key) => Future.sync(() {
        final shared = ref.watch(preparedGroupReadsProvider(key.access));
        if (shared == null) throw RequestCancelledError();
        final details = ref.watch(preparedViewerDetailsProvider(key).future);
        return _preparePhase(ref, key, () async {
          await details;
          return shared.firstPage(key.page);
        });
      }),
      dependencies: [
        contentGroupSourceProvider,
        preparedGroupReadsProvider,
        preparedViewerDetailsProvider,
      ],
    );

Future<T> _preparePhase<T>(
  Ref ref,
  PreparedViewerKey key,
  Future<T> Function() action,
) async {
  final source = ref.watch(contentGroupSourceProvider(key.access));
  final token = CancelToken();
  ref.onDispose(() => token.cancel('Viewer window moved'));
  bool current() =>
      !token.isCancelled &&
      identical(ref.read(contentGroupSourceProvider(key.access)), source);
  var started = false;
  while (true) {
    try {
      return await runWithApiRequestContext(
        ApiRequestContext(
          requestClass: key.foreground
              ? ApiRequestClass.interactive
              : ApiRequestClass.preload,
          allowCooldownRetry: false,
          cancelToken: token,
          canStart: current,
          canAdmit: current,
          onStarted: () => started = true,
        ),
        action,
      );
    } catch (error) {
      final retryAt = switch (error) {
        RateLimitedError(:final retryAt) => retryAt,
        ApiCooldownException(:final retryAt) => retryAt,
        DioException(error: ApiCooldownException(:final retryAt)) => retryAt,
        _ => null,
      };
      if (key.foreground || started || retryAt == null || !current()) rethrow;
      final delay = retryAt.difference(DateTime.now());
      if (delay <= Duration.zero) rethrow;
      final wake = Completer<void>();
      final timer = Timer(delay, wake.complete);
      try {
        await Future.any([wake.future, token.whenCancel]);
      } finally {
        timer.cancel();
      }
      if (!current()) throw RequestCancelledError();
    }
  }
}

class PreparedGroupWindow extends InheritedWidget {
  const PreparedGroupWindow({
    required this.slots,
    required super.child,
    super.key,
  });
  final Map<Object, PreparedViewerKey> slots;
  static PreparedViewerKey? keyOf(BuildContext context, Object occurrence) =>
      context
          .dependOnInheritedWidgetOfExactType<PreparedGroupWindow>()
          ?.slots[occurrence];
  @override
  bool updateShouldNotify(PreparedGroupWindow oldWidget) =>
      oldWidget.slots != slots;
}

/// Read-only order resolution mirrors the native galleries' PageStorage keys.
String? preparedGroupOrder(
  BuildContext context,
  WidgetRef ref,
  GroupViewerEntry entry,
) {
  final reference = entry.summary.reference;
  if (reference.sourceKey.startsWith('related:')) {
    final stored = PageStorage.maybeOf(context)?.readState(
      context,
      identifier: (entry.occurrenceId, 'related-order'),
    ) as RelatedPostsOrder?;
    if (stored != null) return stored.name;
    final libraryState = ref.watch(bookmarkProvider);
    final library = libraryState.valueOrNull;
    if (library == null && libraryState.isLoading) return null;
    final id =
        library?.idByContent[(
          siteNamespace: reference.siteNamespace,
          kind: ContentKind.group,
          sourceKey: reference.sourceKey,
        )];
    final record = library?.byId[id];
    final saved = switch (record) {
      native.RelatedBookmark(:final preferredOrder) => preferredOrder,
      legacy.LegacyRelatedGroupBookmark(:final preferredOrder) =>
        preferredOrder,
      _ => null,
    };
    return (saved ?? ref.watch(settingsProvider).relatedPostsOrder).name;
  }
  final order = PageStorage.maybeOf(context)
      ?.readState(context, identifier: (entry.occurrenceId, 'order'));
  return order is Enum ? order.name : 'order';
}
