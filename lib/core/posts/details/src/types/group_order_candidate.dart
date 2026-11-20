import 'package:dio/dio.dart';

import '../../../../content/groups/group_members_provider.dart';
import '../../../../content/types.dart';

/// A prepared presentation may publish only while its original host exists.
abstract interface class GroupOrderCandidate {
  bool get isReady;
  bool get canAdopt;
  void adopt();
  void dispose();
}

typedef PrepareGroupTimelineOrder = Future<GroupOrderCandidate> Function(
  String order,
  CancelToken cancellation,
);

typedef AdoptGroupMediaOrder = bool Function(
  GroupLoadKey key,
  GroupMembersState snapshot,
);
