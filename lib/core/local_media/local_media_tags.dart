import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../boorus/danbooru/tags/tag/providers.dart';
import '../../boorus/gelbooru/tags/utils.dart';
import '../boorus/booru/types.dart';
import '../configs/config/types.dart';
import '../posts/details_parts/widgets.dart' show RawTagsTile;
import '../router.dart';
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

class LocalMediaTagsTile extends ConsumerWidget {
  const LocalMediaTagsTile({required this.tags, super.key});

  final List<LocalMediaTag> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RawTagsTile(
      title: Text(context.t.tags.counter(n: tags.length)),
      children: [
        PostTagList(
          tags: createTagGroupItems([
            for (final tag in tags)
              Tag.noCount(
                name: tag.name,
                category: stringToGelbooruTagCategory(tag.category),
              ),
          ]),
          itemBuilder: (_, tag) => PostTagListChip(
            tag: tag,
            auth: localMediaTagAuth,
            onTap: () =>
                ref.pushRoute<void>('/local-media-search', extra: tag.rawName),
          ),
        ),
      ],
    );
  }
}
