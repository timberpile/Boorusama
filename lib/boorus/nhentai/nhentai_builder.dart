import '../../core/boorus/defaults/widgets.dart';
import '../../core/boorus/engine/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/widgets.dart';
import '../../core/configs/manage/widgets.dart';
import '../../core/posts/details/widgets.dart';
import '../../core/posts/post/types.dart';
import '../../core/search/suggestions/tag_suggestion_item.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../core/posts/details_parts/types.dart';
import 'config_page.dart';
import 'galleries/page_parent_gallery_section.dart';
import 'posts/data.dart';
import 'search/page.dart';
import 'tags/presentation.dart';

class NhentaiBuilder extends BaseBooruBuilder {
  @override
  CreateConfigPageBuilder get createConfigPageBuilder =>
      (context, id, {backgroundColor}) => CreateBooruConfigScope(
        id: id,
        config: BooruConfig.defaultConfig(
          booruType: id.booruType,
          url: id.url,
          customDownloadFileNameFormat: null,
        ),
        child: NhentaiConfigPage(backgroundColor: backgroundColor),
      );

  @override
  UpdateConfigPageBuilder get updateConfigPageBuilder =>
      (context, id, {backgroundColor, initialTab}) => UpdateBooruConfigScope(
        id: id,
        child: NhentaiConfigPage(
          backgroundColor: backgroundColor,
          initialTab: initialTab,
        ),
      );

  @override
  FavoritesPageBuilder get favoritesPageBuilder =>
      (context) => const NhentaiFavoritesPage();

  @override
  HomeViewBuilder get homeViewBuilder =>
      (context) => const NhentaiHomePage();
  @override
  late final postPresentation = TypedBooruPostPresentation<NhentaiPostData>(
    typeKey: 'nhentai',
    uiBuilder: postDetailsUIBuilder,
  );
  @override
  SearchPageBuilder get searchPageBuilder =>
      (context, params) => NhentaiSearchPage(params: params);
  @override
  TagSuggestionItemBuilder get tagSuggestionItemBuilder =>
      (config, tag, dense, query, onTap) => Consumer(
        builder: (context, ref, _) {
          final section = NhentaiTagSection.fromSource(tag.category);
          return TagSuggestionItem(
            key: ValueKey(tag.value),
            onItemTap: onTap,
            tag: tag,
            dense: dense,
            currentQuery: query,
            textColor: section.color(context, ref, config),
            showCount: tag.hasCount,
            metatagExtractor: null,
            categoryLabel: section == NhentaiTagSection.tags
                ? context.t.nhentai.tags.tag
                : section.label(context),
          );
        },
      );

  @override
  final postDetailsUIBuilder = PostDetailsUIBuilder(
    preview: kFallbackPostDetailsUIBuilder.preview,
    full: {
      DetailsPart.toolbar:
          kFallbackPostDetailsUIBuilder.full[DetailsPart.toolbar]!,
      DetailsPart.fileDetails:
          kFallbackPostDetailsUIBuilder.full[DetailsPart.fileDetails]!,
      DetailsPart.parentWork: (_) => const NhentaiPageParentGallerySection(),
    },
  );

  @override
  PostDetailsPageBuilder get postDetailsPageBuilder =>
      (context, payload) => MixedPostDetailsPageAdapter(payload: payload);
}
