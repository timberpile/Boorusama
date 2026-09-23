// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class Shimmie2PostCodec implements BooruPostDataCodec<Shimmie2PostData> {
  const Shimmie2PostCodec();

  @override
  String get typeKey => 'shimmie2';

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) => data is Shimmie2PostData;

  @override
  Map<String, Object?> encode(Shimmie2PostData data) => {
    if (data.locked case final value?) 'locked': value,
    if (data.ext case final value?) 'ext': value,
    if (data.mime case final value?) 'mime': value,
    if (data.niceName case final value?) 'niceName': value,
    if (data.tooltip case final value?) 'tooltip': value,
    if (data.favorites case final value?) 'favorites': value,
    if (data.numericScore case final value?) 'numericScore': value,
    if (data.notes case final value?) 'notes': value,
    if (data.hasChildren case final value?) 'hasChildren': value,
    if (data.title case final value?) 'title': value,
    if (data.approved case final value?) 'approved': value,
    if (data.approvedById case final value?) 'approvedById': value,
    if (data.isPrivate case final value?) 'isPrivate': value,
    if (data.trash case final value?) 'trash': value,
    if (data.ownerJoinDate case final value?)
      'ownerJoinDate': value.toUtc().toIso8601String(),
    if (data.votes case final votes?)
      'votes': [
        for (final vote in votes)
          {
            if (vote.score case final value?) 'score': value,
            if (vote.userName case final value?) 'userName': value,
            if (vote.userId case final value?) 'userId': value,
          },
      ],
    if (data.myVote case final value?) 'myVote': value,
    if (data.comments case final comments?)
      'comments': [
        for (final comment in comments)
          {
            if (comment.id case final value?) 'id': value,
            if (comment.comment case final value?) 'comment': value,
            if (comment.posted case final value?)
              'posted': value.toUtc().toIso8601String(),
            if (comment.ownerName case final value?) 'ownerName': value,
            if (comment.ownerId case final value?) 'ownerId': value,
          },
      ],
  };

  @override
  Shimmie2PostData decode(
    Map<String, Object?> json, {
    required int version,
  }) {
    if (version != 1) {
      throw const FormatException('Unsupported Shimmie2 post data');
    }
    return Shimmie2PostData(
      locked: json['locked'] as bool?,
      ext: json['ext'] as String?,
      mime: json['mime'] as String?,
      niceName: json['niceName'] as String?,
      tooltip: json['tooltip'] as String?,
      favorites: json['favorites'] as int?,
      numericScore: json['numericScore'] as int?,
      notes: json['notes'] as int?,
      hasChildren: json['hasChildren'] as bool?,
      title: json['title'] as String?,
      approved: json['approved'] as bool?,
      approvedById: json['approvedById'] as int?,
      isPrivate: json['isPrivate'] as bool?,
      trash: json['trash'] as bool?,
      ownerJoinDate: _optionalDate(json['ownerJoinDate']),
      votes: _optionalList(json['votes'])?.map((value) {
        final map = _map(value);
        return Shimmie2VoteData(
          score: map['score'] as int?,
          userName: map['userName'] as String?,
          userId: map['userId'] as int?,
        );
      }).toList(),
      myVote: json['myVote'] as int?,
      comments: _optionalList(json['comments'])?.map((value) {
        final map = _map(value);
        return Shimmie2CommentData(
          id: map['id'] as int?,
          comment: map['comment'] as String?,
          posted: _optionalDate(map['posted']),
          ownerName: map['ownerName'] as String?,
          ownerId: map['ownerId'] as int?,
        );
      }).toList(),
    );
  }
}

Post shimmie2PostFromRecord(Shimmie2PostRecord post, PostOrigin origin) => Post(
  origin: origin,
  core: PostCoreData.fromPost(post),
  booruData: Shimmie2PostData(
    locked: post.locked,
    ext: post.ext,
    mime: post.mime,
    niceName: post.niceName,
    tooltip: post.tooltip,
    favorites: post.favorites,
    numericScore: post.numericScore,
    notes: post.notes,
    hasChildren: post.hasChildren,
    title: post.title,
    approved: post.approved,
    approvedById: post.approvedById,
    isPrivate: post.private,
    trash: post.trash,
    ownerJoinDate: post.ownerJoinDate,
    votes: post.votes
        ?.map(
          (vote) => Shimmie2VoteData(
            score: vote.score,
            userName: vote.userName,
            userId: vote.userId,
          ),
        )
        .toList(),
    myVote: post.myVote,
    comments: post.comments
        ?.map(
          (comment) => Shimmie2CommentData(
            id: comment.id,
            comment: comment.comment,
            posted: comment.posted,
            ownerName: comment.ownerName,
            ownerId: comment.ownerId,
          ),
        )
        .toList(),
  ),
);

DateTime? _optionalDate(Object? value) => switch (value) {
  final String date => DateTime.parse(date),
  null => null,
  _ => throw const FormatException('Invalid date'),
};

List<Object?>? _optionalList(Object? value) => switch (value) {
  final List<Object?> values => values,
  null => null,
  _ => throw const FormatException('Invalid list'),
};

Map<String, Object?> _map(Object? value) => switch (value) {
  final Map<String, Object?> map => map,
  _ => throw const FormatException('Invalid map'),
};
