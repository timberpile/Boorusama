// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/widgets.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../search/search/routes.dart';
import '../../../../widgets/widgets.dart';
import '../../../listing/widgets.dart';
import '../../../post/providers.dart';
import '../../../post/types.dart';

class FavoritesPageScaffold<T extends Post> extends ConsumerWidget {
  const FavoritesPageScaffold({
    required this.fetcher,
    required this.favQueryBuilder,
    super.key,
  });

  final PostsOrError<T> Function(int page) fetcher;
  final String Function()? favQueryBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfig;
    final origin = PostOrigin.fromSource(
      booruType: config.auth.booruType,
      booruId: config.booruId,
      source: config.url,
      profileIdHint: config.id,
    );
    final converter =
        ref.watch(booruPostConverterProvider(config.auth.booruType)) ??
        (Post post, PostOrigin origin) => UnifiedPost(
          origin: origin,
          core: PostCoreData.fromPost(post),
          booruData: LegacyPostData(
            typeKey: 'legacy_${origin.booruType.name}',
            custom: const {},
          ),
        );

    return CustomContextMenuOverlay(
      child: PostScope<UnifiedPost>(
        fetcher: (page) => fetcher(page).map(
          (result) => convertPostResult(
            result,
            origin: origin,
            converter: converter,
          ),
        ),
        builder: (context, controller) => PostGrid(
          controller: controller,
          sliverHeaders: [
            SliverAppBar(
              title: Text(context.t.profile.favorites),
              floating: true,
              elevation: 0,
              shadowColor: Colors.transparent,
              backgroundColor: Kurumi.themeOf(context).colorScheme.surface,
              actions: [
                if (favQueryBuilder != null)
                  IconButton(
                    icon: const Icon(Symbols.search),
                    onPressed: () {
                      goToSearchPage(
                        ref,
                        tag: favQueryBuilder!(),
                      );
                    },
                  ),
              ],
            ),
            const SliverSizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}
