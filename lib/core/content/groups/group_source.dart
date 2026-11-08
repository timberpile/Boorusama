import 'package:foundation/foundation.dart';

import '../../errors/types.dart';
import '../content_access.dart';
import '../content_reference.dart';
import 'group_details.dart';
import 'group_member.dart';
import 'group_summary.dart';

abstract class ContentGroupSource {
  ContentAccessContext get access;
  TaskEither<BooruError, ContentGroupSummary> loadSummary(
    ContentReference reference,
  );
  TaskEither<BooruError, ContentGroupDetails> loadDetails(
    ContentReference reference,
  );
  TaskEither<BooruError, GroupMemberBatch> loadMembers(GroupMemberQuery query);

  /// Cached adapters invalidate their raw envelope; uncached adapters need no work.
  void invalidate(ContentReference reference) {}
  void dispose() {}
}

/// Optional native page access for galleries with a numeric page selector.
/// Implementations validate the ordinal and keep cursor encoding source-owned.
abstract interface class IndexedGroupMemberSource {
  TaskEither<BooruError, GroupMemberBatch> loadMemberPage(
    GroupMemberQuery query, {
    required int page,
  });
}
