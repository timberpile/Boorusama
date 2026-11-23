import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content_access.dart';
import '../content_reference.dart';
import 'group_source.dart';
import 'group_source_provider.dart';
import 'group_details.dart';
import 'group_member.dart';
import 'owned_read_cache.dart';

typedef PreparedGroupPageKey = ({
  ContentReference reference,
  String? order,
  int limit,
  int revision,
});

/// Source lifetime bounds shared results; occurrences retain their own viewport.
final preparedGroupReadsProvider = Provider.autoDispose
    .family<PreparedGroupReads?, ContentAccessKey>((ref, key) {
      final source = ref
          .watch(contentGroupSourceStateProvider(key))
          .asData
          ?.value;
      if (source == null) return null;
      final reads = PreparedGroupReads(source);
      ref.onDispose(reads.dispose);
      return reads;
    }, dependencies: [contentGroupSourceStateProvider]);

class PreparedGroupReads {
  PreparedGroupReads(this.source);
  final ContentGroupSource source;
  final _details =
      OwnedReadCache<(ContentReference, int), ContentGroupDetails>();
  final _pageKeys = <ContentReference, Set<PreparedGroupPageKey>>{};
  final _pages = OwnedReadCache<PreparedGroupPageKey, GroupMemberBatch>();

  Future<ContentGroupDetails> details(
    ContentReference reference,
    int revision,
  ) => _details.load(
    (reference, revision),
    () => source
        .loadDetails(reference)
        .run()
        .then((r) => r.fold((e) => throw e, (r) => r)),
  );

  Future<GroupMemberBatch> firstPage(PreparedGroupPageKey key) {
    _pageKeys.putIfAbsent(key.reference, () => {}).add(key);
    return _pages.load(key, () async {
      final query = GroupMemberQuery(
        reference: key.reference,
        orderKey: key.order,
        requestedLimit: key.limit,
      );
      final request = source is IndexedGroupMemberSource
          ? (source as IndexedGroupMemberSource).loadMemberPage(query, page: 1)
          : source.loadMembers(query);
      final batch = await request.run().then(
        (r) => r.fold((e) => throw e, (r) => r),
      );
      return validateGroupMemberBatch(query, batch);
    });
  }

  void invalidate(ContentReference reference, int revision) {
    _details.invalidate((reference, revision));
    for (final key in _pageKeys[reference] ?? <PreparedGroupPageKey>{}) {
      if (key.revision == revision) _pages.invalidate(key);
    }
    _pageKeys[reference]?.removeWhere((key) => key.revision == revision);
  }

  void dispose() {
    _details.dispose();
    _pages.dispose();
  }
}
