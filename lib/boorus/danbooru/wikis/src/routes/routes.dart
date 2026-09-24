// Project imports:
import '../../../../../core/configs/config/types.dart';
import '../../../../../core/configs/manage/widgets.dart';
import '../../../../../core/router.dart';
import '../pages/danbooru_wiki_page.dart';

final danbooruWikiRoutes = GoRoute(
  path: '/danbooru/wiki_pages/:wikiPageName',
  name: 'danbooru_wiki',
  pageBuilder: largeScreenAwarePageBuilder(
    builder: (context, state) {
      final wikiPageName = state.pathParameters['wikiPageName'];

      if (wikiPageName == null || wikiPageName.isEmpty) {
        return const InvalidPage(message: 'Invalid wiki title');
      }

      final page = DanbooruWikiPage(wikiPageName: wikiPageName);
      return switch (state.extra) {
        final BooruConfig config => CurrentBooruConfigScope(
          config: config,
          child: page,
        ),
        _ => page,
      };
    },
  ),
);
