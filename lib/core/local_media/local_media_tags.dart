import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../boorus/danbooru/tags/tag/providers.dart';
import '../boorus/booru/types.dart';
import '../configs/config/types.dart';
import '../posts/details_parts/widgets.dart' show RawTagsTile;
import '../tags/categories/types.dart';
import '../tags/tag/types.dart';
import '../tags/tag/widgets.dart';
import 'local_media_models.dart';

/// Local tags use the public Danbooru vocabulary without borrowing an account.
final localMediaTagAuth = BooruConfig.defaultConfig(
  booruType: BooruType.danbooru,
  url: 'https://danbooru.donmai.us',
  customDownloadFileNameFormat: null,
).auth;

final localMediaTagLookupProvider =
    Provider<Future<List<Tag>> Function(Set<String>)>((ref) {
      return (names) => ref
          .read(danbooruTagResolverProvider(localMediaTagAuth))
          .resolveRawTags(names);
    });

class LocalMediaTagsTile extends StatelessWidget {
  const LocalMediaTagsTile({required this.tags, super.key});

  final List<LocalMediaTag> tags;

  @override
  Widget build(BuildContext context) {
    return RawTagsTile(
      title: Text(context.t.tags.counter(n: tags.length)),
      children: [
        PostTagList(
          tags: createTagGroupItems([
            for (final tag in tags)
              Tag.noCount(
                name: tag.name,
                category: TagCategory.fromLegacyIdString(tag.category),
              ),
          ]),
          itemBuilder: (_, tag) => PostTagListChip(
            tag: tag,
            auth: localMediaTagAuth,
          ),
        ),
      ],
    );
  }
}
