import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/types.dart';

ContentAccessContext galleryAccess() => ContentAccessContext.profile(
  config: BooruConfig.fromJson({
    ...BooruConfig.empty.toJson(),
    'id': '11111111-1111-4111-8111-111111111111',
    'url': 'https://nhentai.net',
    'booruId': BooruType.nhentai.id,
    'booruIdHint': BooruType.nhentai.id,
  }),
  authEpoch: 1,
  policyEpoch: 1,
);

NhentaiMediaPolicy galleryPolicy() => NhentaiMediaPolicy(
  imageServers: ['https://i1.nhentai.net'],
  thumbnailServers: ['https://t1.nhentai.net'],
);

Map<String, dynamic> galleryJson({
  Object? tags = const [
    {'id': 5, 'type': 'tag', 'name': 'fixture'},
  ],
  bool omitTags = false,
}) => {
  'id': 101,
  'media_id': '7001',
  'title': {'english': 'Fixture Gallery'},
  'num_pages': 3,
  'upload_date': 1700000000,
  'thumbnail': {
    'path': 'galleries/7001/thumb.webp',
    'width': 250,
    'height': 350,
  },
  if (!omitTags) 'tags': tags,
  'pages': [
    {
      'number': 1,
      'path': 'galleries/7001/1.webp',
      'width': 100,
      'height': 200,
      'thumbnail': 'galleries/7001/1t.webp',
    },
    {'number': 2},
    {'number': 3, 'path': 'galleries/7001/3.webp', 'width': 110, 'height': 210},
  ],
};
