import 'package:kurumi/material.dart';

import '../../../../content/types.dart';
import 'group_order_candidate.dart';

/// Reading state belongs to an outer occurrence, never to a shared Work cache.
class MediaGroupCheckpoint {
  MediaGroupCheckpoint({this.memberKey});
  String? memberKey;
  var visited = false;
  var timelineOffset = 0.0;
  ValueChanged<int>? navigate;
  PageController? pages;
  AdoptGroupMediaOrder? adoptMediaOrder;
  bool Function()? canAdoptOrder;
  final transforms = <Object, Matrix4>{};

  int? indexIn(List<GroupMember> members) {
    if (memberKey == null) return members.isEmpty ? null : 0;
    final index = members.indexWhere((member) => member.memberKey == memberKey);
    return index < 0 ? null : index;
  }

  void select(GroupMember member) => memberKey = member.memberKey;
}
