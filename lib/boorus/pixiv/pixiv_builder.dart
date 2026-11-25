import 'package:flutter/foundation.dart';

// Project imports:
import '../../core/boorus/defaults/widgets.dart';
import '../../core/boorus/engine/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/widgets.dart';
import '../../core/configs/manage/widgets.dart';
import '../../core/home/types.dart';
import '../../core/posts/details/widgets.dart';
import '../../core/posts/details_parts/types.dart';
import '../../core/posts/details_parts/src/toolbars/viewer_toolbar_profile_actions.dart';
import '../../core/posts/details_parts/widgets.dart';
import '../../core/posts/post/types.dart';
import 'configs/widgets.dart';
import 'configs/extra_data.dart';
import 'favorites/favorite_control.dart';
import 'home/custom_home.dart';
import 'favorites/page.dart';
import 'posts/types.dart';
import 'ugoira/ugoira_media.dart';
import 'works/search_page.dart';
import 'works/work_information.dart';
import 'works/page_parent_work_section.dart';
import 'works/related_section.dart';
import 'works/author_section.dart';

class PixivBuilder extends BaseBooruBuilder {
  PixivBuilder();

  @override
  HomeViewBuilder get homeViewBuilder =>
      (context) => const PixivWorkHomePage();

  @override
  SearchPageBuilder get searchPageBuilder =>
      (context, params) => PixivWorkSearchPage(params: params);

  @override
  late final postPresentation = TypedBooruPostPresentation<PixivPostData>(
    typeKey: 'pixiv',
    uiBuilder: postDetailsUIBuilder,
    detailsImageBuilder: buildPixivUgoiraMedia,
  );

  @override
  CreateConfigPageBuilder get createConfigPageBuilder =>
      (
        context,
        id, {
        backgroundColor,
      }) => CreateBooruConfigScope(
        id: id,
        config: BooruConfig.defaultConfig(
          booruType: id.booruType,
          url: id.url,
          customDownloadFileNameFormat: null,
        ),
        child: CreatePixivConfigPage(
          backgroundColor: backgroundColor,
        ),
      );

  /// Without this the default update page would be the anonymous one, which
  /// has no auth tab — leaving no way to re-login and making the session
  /// expired dialog's `?q=auth` deep link land on a page that cannot honour
  /// it.
  @override
  UpdateConfigPageBuilder get updateConfigPageBuilder =>
      (
        context,
        id, {
        backgroundColor,
        initialTab,
      }) => UpdateBooruConfigScope(
        id: id,
        child: CreatePixivConfigPage(
          backgroundColor: backgroundColor,
          initialTab: initialTab,
        ),
      );

  @override
  FavoritesPageBuilder get favoritesPageBuilder =>
      (context) => const PixivFavoritesPage();

  @override
  QuickFavoriteButtonBuilder get quickFavoriteButtonBuilder =>
      (
        context,
        ref,
        post,
      ) {
        final artwork = post.pixivData;
        if (artwork == null || artwork.isRestricted) return null;
        return PixivFavoriteControl(
          key: ValueKey(artwork.illustId),
          illustId: artwork.illustId,
          compact: true,
        );
      };

  @override
  PostDetailsPageBuilder get postDetailsPageBuilder =>
      (context, payload) => MixedPostDetailsPageAdapter(
        payload: payload,
      );

  /// Pixiv illusts carry a meaningful tag pool, so the tags section stays
  /// part of the details UI.
  @override
  final postDetailsUIBuilder = PostDetailsUIBuilder(
    viewerToolbarProfileActions: (ref, auth) => standardViewerToolbarActions(
      ref,
      auth,
      favorite:
          auth.anonymousReadScope == null &&
          pixivAuthenticatedUserId(auth) != null,
    ),
    preview: {
      DetailsPart.toolbar: (context) => const PixivPostFavoriteToolbar(),
    },
    full: {
      DetailsPart.toolbar: (context) => const PixivPostFavoriteToolbar(),
      DetailsPart.artistInfo: (context) => const PixivWorkInformation(),
      DetailsPart.tags: (context) => const DefaultInheritedTagsTile<Post>(),
      DetailsPart.fileDetails: (context) =>
          const DefaultInheritedFileDetailsSection<Post>(),
      DetailsPart.artistPosts: (context) => const PixivAuthorWorksSection(),
      DetailsPart.parentWork: (context) => const PixivParentWorkSection(),
      DetailsPart.relatedPosts: (context) => const PixivRelatedWorksSection(),
    },
  );

  @override
  Map<CustomHomeViewKey, CustomHomeDataBuilder> get customHomeViewBuilders =>
      pixivCustomHome;
}
