import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/types.dart';

ContentAccessContext workAccess({
  String id = '11111111-1111-4111-8111-111111111111',
  String site = 'https://www.pixiv.net',
}) => ContentAccessContext.profile(
  config: BooruConfig.fromJson({
    ...BooruConfig.empty.toJson(),
    'id': id,
    'url': site,
    'booruId': BooruType.pixiv.id,
    'booruIdHint': BooruType.pixiv.id,
  }),
  authEpoch: 1,
  policyEpoch: 1,
);

PixivIllustDto work({
  int id = 120,
  int? pageCount = 3,
  List<Object?>? pages,
  String type = 'manga',
  bool visible = true,
  bool muted = false,
  String? original,
}) => PixivIllustDto.fromJson({
  'id': id,
  'title': 'Work $id',
  'type': type,
  'caption': '<p>Work caption</p>',
  'user': {'id': 7, 'name': 'Artist', 'account': 'artist'},
  'page_count': pageCount,
  'width': 1200,
  'height': 1800,
  'x_restrict': 0,
  'sanity_level': 2,
  'visible': visible,
  'is_muted': muted,
  'create_date': '2026-01-01T12:00:00+09:00',
  'image_urls': {
    'square_medium': 'https://i.pximg.net/thumb/${id}_p0.jpg',
    'large': 'https://i.pximg.net/large/${id}_p0.jpg',
  },
  'tags': [
    {'name': 'fixture', 'translated_name': 'Fixture'},
  ],
  'meta_single_page': {
    'original_image_url':
        original ?? 'https://i.pximg.net/original/${id}_p0.jpg',
  },
  'meta_pages':
      pages ??
      [
        for (var index = 0; index < (pageCount ?? 3); index++) page(id, index),
      ],
});

Map<String, Object?> page(int illustId, int index, {String? original}) => {
  'image_urls': {
    'original':
        original ?? 'https://i.pximg.net/original/${illustId}_p$index.jpg',
    'square_medium': 'https://i.pximg.net/thumb/${illustId}_p$index.jpg',
    'large': 'https://i.pximg.net/large/${illustId}_p$index.jpg',
  },
};
