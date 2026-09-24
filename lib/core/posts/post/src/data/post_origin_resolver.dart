// Project imports:
import '../../../../boorus/booru/types.dart';
import '../../../../configs/config/types.dart';
import '../types/post_origin.dart';
import '../types/post_origin_resolution.dart';

final class PostOriginResolver {
  const PostOriginResolver();

  PostOriginResolution resolve(
    PostOrigin origin,
    Iterable<BooruConfig> configs,
  ) {
    final candidates = configs.toList(growable: false);
    if (origin.profileIdHint case final profileId?) {
      final hinted = candidates
          .where((config) => config.id == profileId)
          .toList(growable: false);
      if (hinted.length == 1 && _matches(hinted.single, origin)) {
        final config = hinted.single;
        return ResolvedPostOrigin(config);
      }
    }

    final matches = candidates
        .where((config) => _matches(config, origin))
        .toList(growable: false);

    return switch (matches) {
      [final config] => ResolvedPostOrigin(config),
      [] => const MissingPostOrigin(),
      _ => const AmbiguousPostOrigin(),
    };
  }

  bool _matches(BooruConfig config, PostOrigin origin) =>
      intToBooruType(config.booruIdHint) == origin.booruType &&
      normalizePostSourceHost(config.url) == origin.sourceHost;
}
