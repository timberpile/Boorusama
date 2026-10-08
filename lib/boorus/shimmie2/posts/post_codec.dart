// Project imports:
import '../../../core/posts/post/types.dart';
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
    'locked': ?data.locked,
    'ext': ?data.ext,
    'mime': ?data.mime,
    'niceName': ?data.niceName,
    'tooltip': ?data.tooltip,
    'favorites': ?data.favorites,
    'numericScore': ?data.numericScore,
    'notes': ?data.notes,
    'hasChildren': ?data.hasChildren,
    'title': ?data.title,
    'approved': ?data.approved,
    'approvedById': ?data.approvedById,
    'isPrivate': ?data.isPrivate,
    'trash': ?data.trash,
    if (data.ownerJoinDate case final value?)
      'ownerJoinDate': value.toUtc().toIso8601String(),
    if (data.votes case final votes?)
      'votes': [
        for (final vote in votes)
          {
            'score': ?vote.score,
            'userName': ?vote.userName,
            'userId': ?vote.userId,
          },
      ],
    'myVote': ?data.myVote,
    if (data.comments case final comments?)
      'comments': [
        for (final comment in comments)
          {
            'id': ?comment.id,
            'comment': ?comment.comment,
            if (comment.posted case final value?)
              'posted': value.toUtc().toIso8601String(),
            'ownerName': ?comment.ownerName,
            'ownerId': ?comment.ownerId,
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
  final Map<Object?, Object?> map when map.keys.every((key) => key is String) =>
    Map<String, Object?>.from(map),
  _ => throw const FormatException('Invalid map'),
};
