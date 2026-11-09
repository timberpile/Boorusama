import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/search/routes.dart';
import '../../../core/search/search/widgets.dart';
import '../../../core/search/search/src/widgets/search_page_scaffold.dart';
import '../../../core/search/search/src/widgets/search_profile_session.dart';
import '../../../core/search/syntax/providers.dart';
import '../../../core/search/queries/providers.dart';
import '../client_provider.dart';
import '../posts/query.dart';
import 'work_listing.dart';

/// Keeps normal query editing, autocomplete, Following and profile navigation;
/// only the result capability becomes native Work entries.
class PixivWorkSearchPage extends ConsumerWidget {
  const PixivWorkSearchPage({required this.params, super.key});
  final SearchParams params;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (SearchProfileSession.maybeOf(context)?.local ?? false)
      return DefaultSearchPage(params: params);
    final config = ref.watchConfig;
    final compatibility = ref.watch(originAwarePostRepoProvider(config));
    final composer = ref.watch(defaultTagQueryComposerProvider(config.search));
    return SearchPageScaffold<Post>(
      params: params,
      textMatchers: [?ref.watch(queryMatcherProvider(config.auth))],
      fetcher: (page, controller) =>
          compatibility.getPostsFromController(controller.tagSet, page),
      nativeResultBuilder: (context, queryText, initialPage, header) {
        final composed = composer.compose(queryText.split(' '));
        final query = PixivQuery.parse(composed);
        return PixivWorkGrid(
          config: config,
          queryIdentity: (queryText, composed.join(' '), config.search),
          initialPage: initialPage,
          header: header,
          fetchPage: (page) {
            final client = ref.read(pixivClientProvider(config.auth));
            return switch (query) {
              PixivQuery(userId: final id?) => client.getUserIllusts(
                userId: id,
                page: page,
              ),
              PixivQuery(text: final text?) => client.searchIllust(
                word: text,
                page: page,
              ),
              _ => client.getRanking(mode: PixivRankingMode.day, page: page),
            };
          },
        );
      },
    );
  }
}
