// Flutter imports:
import 'package:flutter/widgets.dart';

// Project imports:
import '../../../core/posts/post/types.dart';
import '../../../core/tags/categories/types.dart';
import '../../../core/tags/tag/types.dart';
import '../pools/types.dart';
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
    'status': ?data.status,
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
      ownFavorite: _required<bool>(json['ownFavorite'], 'favorite state'),
      favoriteCount: _required<int>(json['favoriteCount'], 'favorite count'),
      commentCount: _required<int>(json['commentCount'], 'comment count'),
      tagDetails: _list(json['tagDetails']).map(_decodeTag).toList(),
      status: json['status'] as String?,
      pools: _list(json['pools']).map(_decodePool).toList(),
    );
  }
}

Post szurubooruPostFromRecord(SzurubooruPostRecord post, PostOrigin origin) =>
    Post(
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
  'label': ?tag.label,
  'postCount': tag.postCount,
  'category': {
    'id': tag.category.id,
    'name': tag.category.name,
    'displayName': ?tag.category.displayName,
    'originalName': ?tag.category.originalName,
    'order': ?tag.category.order,
    if (tag.category.darkColor case final value?) 'darkColor': value.toARGB32(),
    if (tag.category.lightColor case final value?)
      'lightColor': value.toARGB32(),
  },
};

Tag _decodeTag(Object? value) {
  final map = _map(value);
  final category = _map(map['category']);
  return Tag(
    name: _required<String>(map['name'], 'tag name'),
    label: map['label'] as String?,
    postCount: _required<int>(map['postCount'], 'tag post count'),
    category: TagCategory(
      id: _required<int>(category['id'], 'tag category ID'),
      name: _required<String>(category['name'], 'tag category name'),
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
  'category': ?pool.category,
  'description': ?pool.description,
  'postCount': ?pool.postCount,
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
    id: _required<int>(map['id'], 'pool ID'),
    names: _list(
      map['names'],
    ).map((e) => _required<String>(e, 'pool name')).toList(),
    category: map['category'] as String?,
    description: map['description'] as String?,
    postCount: map['postCount'] as int?,
    postIds: _list(
      map['postIds'],
    ).map((e) => _required<int>(e, 'pool post ID')).toList(),
    thumbnailUrls: _list(
      map['thumbnailUrls'],
    ).map((e) => _required<String>(e, 'pool thumbnail URL')).toList(),
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
  final Map<Object?, Object?> map when map.keys.every((key) => key is String) =>
    Map<String, Object?>.from(map),
  _ => throw const FormatException('Invalid map'),
};

T _required<T>(Object? value, String field) => switch (value) {
  final T value => value,
  _ => throw FormatException('Invalid Szurubooru $field'),
};
