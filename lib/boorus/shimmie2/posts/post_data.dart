// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../core/posts/post/types.dart';

final class Shimmie2PostData extends Equatable implements BooruPostData {
  const Shimmie2PostData({
    required this.locked,
    required this.ext,
    required this.mime,
    required this.niceName,
    required this.tooltip,
    required this.favorites,
    required this.numericScore,
    required this.notes,
    required this.hasChildren,
    required this.title,
    required this.approved,
    required this.approvedById,
    required this.isPrivate,
    required this.trash,
    required this.ownerJoinDate,
    required this.votes,
    required this.myVote,
    required this.comments,
  });

  final bool? locked;
  final String? ext;
  final String? mime;
  final String? niceName;
  final String? tooltip;
  final int? favorites;
  final int? numericScore;
  final int? notes;
  final bool? hasChildren;
  final String? title;
  final bool? approved;
  final int? approvedById;
  final bool? isPrivate;
  final bool? trash;
  final DateTime? ownerJoinDate;
  final List<Shimmie2VoteData>? votes;
  final int? myVote;
  final List<Shimmie2CommentData>? comments;

  @override
  String get typeKey => 'shimmie2';

  @override
  int get schemaVersion => 1;

  @override
  List<Object?> get props => [
    locked,
    ext,
    mime,
    niceName,
    tooltip,
    favorites,
    numericScore,
    notes,
    hasChildren,
    title,
    approved,
    approvedById,
    isPrivate,
    trash,
    ownerJoinDate,
    votes,
    myVote,
    comments,
  ];
}

final class Shimmie2VoteData extends Equatable {
  const Shimmie2VoteData({
    required this.score,
    required this.userName,
    required this.userId,
  });

  final int? score;
  final String? userName;
  final int? userId;

  @override
  List<Object?> get props => [score, userName, userId];
}

final class Shimmie2CommentData extends Equatable {
  const Shimmie2CommentData({
    required this.id,
    required this.comment,
    required this.posted,
    required this.ownerName,
    required this.ownerId,
  });

  final int? id;
  final String? comment;
  final DateTime? posted;
  final String? ownerName;
  final int? ownerId;

  @override
  List<Object?> get props => [id, comment, posted, ownerName, ownerId];
}

extension Shimmie2PostDataX on Post {
  Shimmie2PostData? get shimmie2Data => switch (booruData) {
    final Shimmie2PostData data => data,
    _ => null,
  };

  List<Shimmie2CommentData>? get comments => shimmie2Data?.comments;
}
