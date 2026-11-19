// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/images/booru_image.dart';
import '../../../../../../core/settings/providers.dart';
import '../../types.dart';
import '../providers/pool_covers_notifier.dart';
import '../types/safebooru_pool_availability.dart';
import '../types/pool_cover.dart';

class PoolImage extends ConsumerWidget {
  const PoolImage({
    required this.pool,
    super.key,
  });

  final DanbooruPool pool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = poolCoverSearch(ref.watch);
    final safe = isDonmaiSafebooru(config.auth.url);
    final PoolAssessment? assessment;
    final PoolCover? cover;
    if (safe) {
      ref.watch(danbooruPoolCoversProvider(config));
      assessment = ref
          .read(danbooruPoolCoversProvider(config).notifier)
          .assessment(pool);
      cover = assessment?.covers.firstOrNull;
    } else {
      assessment = null;
      cover = ref.watch(danbooruPoolCoverProvider(pool.id));
    }
    final alternatives = assessment?.covers ?? const <PoolCover>[];
    final imageBorderRadius = ref.watch(
      imageListingSettingsProvider.select((value) => value.imageBorderRadius),
    );

    return LayoutBuilder(
      builder: (context, constraints) => switch (cover?.url) {
        final url? => BooruImage(
          config: ref.watchConfigAuth,
          aspectRatio: 0.6,
          imageUrl: url,
          fallbackUrls: [
            for (final item in alternatives)
              if (item.url != null && item.url != url) item.url!,
          ],
          fit: BoxFit.cover,
          borderRadius: BorderRadius.all(
            Radius.circular(imageBorderRadius),
          ),
        ),
        _ => AspectRatio(
          aspectRatio: 0.6,
          child: Container(
            width: constraints.maxWidth,
            decoration: BoxDecoration(
              color: Kurumi.themeOf(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.all(
                Radius.circular(imageBorderRadius),
              ),
            ),
            child:
                (!safe && cover != null) ||
                    assessment?.availability == PoolAvailability.accessible
                ? Center(
                    child: Text(context.t.pool.no_cover_image),
                  )
                : null,
          ),
        ),
      },
    );
  }
}
