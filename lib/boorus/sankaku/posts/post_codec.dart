// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:booru_clients/sankaku.dart';

// Project imports:
import '../../../core/posts/post/types.dart';
import '../../../core/tags/categories/types.dart';
import '../../../core/tags/tag/types.dart';
import 'post_data.dart';
import 'types.dart';

final class SankakuPostCodec implements BooruPostDataCodec<SankakuPostData> {
  const SankakuPostCodec();

  @override
  String get typeKey => 'sankaku';

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) => data is SankakuPostData;

  @override
  Map<String, Object?> encode(SankakuPostData data) => {
    if (data.sankakuId case final id?)
      'sankakuId': {'value': id.value, 'isNumeric': id.isNumeric},
    'isFavorited': data.isFavorited,
    'favoriteCount': data.favoriteCount,
    'artistDetailsTags': data.artistDetailsTags.map(_encodeTag).toList(),
    'characterDetailsTags': data.characterDetailsTags.map(_encodeTag).toList(),
    'copyrightDetailsTags': data.copyrightDetailsTags.map(_encodeTag).toList(),
    'generalDetailsTags': data.generalDetailsTags.map(_encodeTag).toList(),
    'metaDetailsTags': data.metaDetailsTags.map(_encodeTag).toList(),
  };

  @override
  SankakuPostData decode(
    Map<String, Object?> json, {
    required int version,
  }) {
    if (version != 1) {
      throw const FormatException('Unsupported Sankaku post data');
    }
    return SankakuPostData(
      sankakuId: switch (json['sankakuId']) {
        null => null,
        final value => switch (_map(value)) {
          final map => SankakuPostIdData(
            value: map['value'] as String,
            isNumeric: map['isNumeric'] as bool,
          ),
        },
      },
      isFavorited: json['isFavorited'] as bool,
      favoriteCount: json['favoriteCount'] as int,
      artistDetailsTags: _decodeTags(json['artistDetailsTags']),
      characterDetailsTags: _decodeTags(json['characterDetailsTags']),
      copyrightDetailsTags: _decodeTags(json['copyrightDetailsTags']),
      generalDetailsTags: _decodeTags(json['generalDetailsTags']),
      metaDetailsTags: _decodeTags(json['metaDetailsTags']),
    );
  }
}

Post sankakuPostFromRecord(SankakuPostRecord post, PostOrigin origin) => Post(
  origin: origin,
  core: PostCoreData.fromPost(post),
  booruData: SankakuPostData(
    sankakuId: switch (post.sankakuId) {
      IntId(:final value) => SankakuPostIdData(
        value: value.toString(),
        isNumeric: true,
      ),
      StringId(:final value) => SankakuPostIdData(
        value: value,
        isNumeric: false,
      ),
      null => null,
    },
    isFavorited: post.isFavorited,
    favoriteCount: post.favoriteCount,
    artistDetailsTags: post.artistDetailsTags,
    characterDetailsTags: post.characterDetailsTags,
    copyrightDetailsTags: post.copyrightDetailsTags,
    generalDetailsTags: post.generalDetailsTags,
    metaDetailsTags: post.metaDetailsTags,
  ),
);

Map<String, Object?> _encodeTag(Tag tag) => {
  'name': tag.name,
  if (tag.label case final value?) 'label': value,
  'postCount': tag.postCount,
  'category': {
    'id': tag.category.id,
    'name': tag.category.name,
    if (tag.category.displayName case final value?) 'displayName': value,
    if (tag.category.originalName case final value?) 'originalName': value,
    if (tag.category.order case final value?) 'order': value,
    if (tag.category.darkColor case final value?) 'darkColor': value.toARGB32(),
    if (tag.category.lightColor case final value?)
      'lightColor': value.toARGB32(),
  },
};

List<Tag> _decodeTags(Object? value) => _list(value).map((entry) {
  final map = _map(entry);
  final category = _map(map['category']);
  return Tag(
    name: map['name'] as String,
    label: map['label'] as String?,
    postCount: map['postCount'] as int,
    category: TagCategory(
      id: category['id'] as int,
      name: category['name'] as String,
      displayName: category['displayName'] as String?,
      originalName: category['originalName'] as String?,
      order: category['order'] as int?,
      darkColor: switch (category['darkColor']) {
        final int value => Color(value),
        _ => null,
      },
      lightColor: switch (category['lightColor']) {
        final int value => Color(value),
        _ => null,
      },
    ),
  );
}).toList();

List<Object?> _list(Object? value) => switch (value) {
  final List<Object?> values => values,
  _ => throw const FormatException('Invalid list'),
};

Map<String, Object?> _map(Object? value) => switch (value) {
  final Map<String, Object?> map => map,
  _ => throw const FormatException('Invalid map'),
};
