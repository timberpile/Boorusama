import 'package:foundation/foundation.dart';

import '../../../../../core/bookmarks/src/providers/pool_bookmark_provider.dart';
import '../../../../../core/posts/post/types.dart';
import 'widgets/search_series_grid.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:rich_text_controller/rich_text_controller.dart';

// Project imports:
import '../../../../../core/configs/config/providers.dart';
import '../../../../../core/configs/config/types.dart';
import '../../../../../core/posts/post/providers.dart';
import '../../../../../core/search/search/routes.dart';
import '../../../../../core/search/search/widgets.dart';
import '../../../../../core/search/selected_tags/types.dart';
import '../../../../../core/tags/metatag/widgets.dart';
import '../../../tags/user_metatags/providers.dart';
import 'widgets/danbooru_metatags_section.dart';
import 'widgets/related_tag_section.dart';
import 'widgets/trending_section.dart';

class DanbooruSearchPage extends ConsumerStatefulWidget {
  const DanbooruSearchPage({required this.params, super.key});
  final SearchParams params;

  @override
  ConsumerState<DanbooruSearchPage> createState() => _DanbooruSearchPageState();
}

class _DanbooruSearchPageState extends ConsumerState<DanbooruSearchPage> {
  final _series = SearchSeriesIndex();

  @override
  void dispose() {
    _series.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfig;
    final postRepo = ref.watch(originAwarePostRepoProvider(config));
    final metatags = ref.watch(metatagsProvider).map((e) => e.name).join('|');
    final extractor = ref.watch(danbooruMetatagExtractorProvider(config.auth));
    return SearchPageScaffold<Post>(
      resultGridBuilder: (context, controller, itemBuilder) => SearchSeriesGrid(
        controller: controller,
        index: _series,
        config: config,
        query: InheritedSearchPageController.of(context).tagString.value,
        itemBuilder: itemBuilder,
      ),
      fetcher: (page, controller) => TaskEither(() async {
        final query = controller.rawTagsString;
        final capability = ref.read(poolBookmarkCapabilityProvider(config));
        final result = await postRepo
            .getPostsFromController(controller.tagSet, page)
            .run();
        if (!isExplicitSeriesSearch(query) && capability != null) {
          await result.fold(
            (_) async {},
            (posts) => _series.load(config, posts.posts, capability),
          );
        }
        return result;
      }),
      params: widget.params,
      textMatchers: [
        RegexMatcher(
          pattern: RegExp('($metatags)+:', caseSensitive: false),
          spanBuilder: (match) => WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: MetatagContainer(tag: match.text),
          ),
        ),
      ],
      landingViewBuilder: (controller) =>
          DanbooruSearchLandingView(controller: controller),
      extraHeaders: (context, postController) {
        final controller = InheritedSearchPageController.of(context);
        return [
          SliverToBoxAdapter(
            child: ValueListenableBuilder(
              valueListenable: controller.tagString,
              builder: (context, tags, _) => RelatedTagSection(
                query: tags,
                onAdded: (tag) => controller.tagsController.addTag(
                  TagSearchItem.fromString(tag.tag, extractor: extractor),
                ),
                onNegated: (tag) => controller.tagsController.addTag(
                  TagSearchItem.fromString('-${tag.tag}', extractor: extractor),
                ),
              ),
            ),
          ),
        ];
      },
    );
  }
}

class DanbooruSearchLandingView extends StatelessWidget {
  const DanbooruSearchLandingView({required this.controller, super.key});
  final SearchPageController controller;

  @override
  Widget build(BuildContext context) => SearchLandingView(
    child: DefaultSearchLandingChildren(
      children: [
        DanbooruMetatagsSection(onOptionTap: controller.tapRawMetaTag),
        DefaultMobileFavoriteTagsSection(controller: controller),
        TrendingSection(onTagTap: controller.tapTag),
        DefaultMobileSearchHistorySection(controller: controller),
      ],
    ),
  );
}
