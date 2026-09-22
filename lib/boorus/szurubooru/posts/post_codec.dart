// Flutter imports:
import 'package:flutter/widgets.dart';

// Project imports:
import '../../../core/posts/post/types.dart';
import '../../../core/tags/categories/types.dart';
import '../../../core/tags/tag/types.dart';
import '../pools/types.dart';
import 'post_data.dart';
import 'types.dart';

final class SzurubooruPostCodec
    implements BooruPostDataCodec<SzurubooruPostData> {
  const SzurubooruPostCodec();

  @override
  String get typeKey => 'szurubooru';

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) => data is SzurubooruPostData;

  @override
  Map<String, Object?> encode(SzurubooruPostData data) => {
    'ownFavorite': data.ownFavorite,
    'favoriteCount': data.favoriteCount,
    'commentCount': data.commentCount,
    'tagDetails': data.tagDetails.map(_encodeTag).toList(),
    if (data.status case final value?) 'status': value,
    'pools': data.pools.map(_encodePool).toList(),
  };

  @override
  SzurubooruPostData decode(
    Map<String, Object?> json, {
    required int version,
  }) {
    if (version != 1) {
      throw const FormatException('Unsupported Szurubooru post data');
    }
    return SzurubooruPostData(
      ownFavorite: json['ownFavorite'] as bool,
      favoriteCount: json['favoriteCount'] as int,
      commentCount: json['commentCount'] as int,
      tagDetails: _list(json['tagDetails']).map(_decodeTag).toList(),
      status: json['status'] as String?,
      pools: _list(json['pools']).map(_decodePool).toList(),
    );
  }
}

UnifiedPost szurubooruPostToUnified(SzurubooruPost post, PostOrigin origin) =>
    UnifiedPost(
      origin: origin,
      core: PostCoreData.fromPost(post),
      booruData: SzurubooruPostData(
        ownFavorite: post.ownFavorite,
        favoriteCount: post.favoriteCount,
        commentCount: post.commentCount,
        tagDetails: post.tagDetails,
        status: switch (post.status) {
          StringPostStatus(:final value) => value,
          _ => null,
        },
        pools: post.pools,
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

Tag _decodeTag(Object? value) {
  final map = _map(value);
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
}

Map<String, Object?> _encodePool(SzurubooruPool pool) => {
  'id': pool.id,
  'names': pool.names,
  if (pool.category case final value?) 'category': value,
  if (pool.description case final value?) 'description': value,
  if (pool.postCount case final value?) 'postCount': value,
  'postIds': pool.postIds,
  'thumbnailUrls': pool.thumbnailUrls,
  if (pool.createdAt case final value?)
    'createdAt': value.toUtc().toIso8601String(),
  if (pool.updatedAt case final value?)
    'updatedAt': value.toUtc().toIso8601String(),
};

SzurubooruPool _decodePool(Object? value) {
  final map = _map(value);
  return SzurubooruPool(
    id: map['id'] as int,
    names: _list(map['names']).map((e) => e as String).toList(),
    category: map['category'] as String?,
    description: map['description'] as String?,
    postCount: map['postCount'] as int?,
    postIds: _list(map['postIds']).map((e) => e as int).toList(),
    thumbnailUrls: _list(
      map['thumbnailUrls'],
    ).map((e) => e as String).toList(),
    createdAt: _optionalDate(map['createdAt']),
    updatedAt: _optionalDate(map['updatedAt']),
  );
}

DateTime? _optionalDate(Object? value) => switch (value) {
  final String date => DateTime.parse(date),
  null => null,
  _ => throw const FormatException('Invalid date'),
};

List<Object?> _list(Object? value) => switch (value) {
  final List<Object?> values => values,
  _ => throw const FormatException('Invalid list'),
};

Map<String, Object?> _map(Object? value) => switch (value) {
  final Map<String, Object?> map => map,
  _ => throw const FormatException('Invalid map'),
};
