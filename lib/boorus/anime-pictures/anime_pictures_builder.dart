// Project imports:
import '../../core/boorus/defaults/widgets.dart';
import '../../core/boorus/engine/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/widgets.dart';
import '../../core/configs/manage/widgets.dart';
import '../../core/posts/details/widgets.dart';
import '../../core/posts/details_parts/types.dart';
import '../../core/posts/details_parts/widgets.dart';
import '../../core/posts/post/types.dart';
import 'configs/widgets.dart';
import 'favorites/widgets.dart';
import 'home/widgets.dart';
import 'posts/post_data.dart';
import 'posts/types.dart';
import 'posts/widgets.dart';
import 'users/widgets.dart';

class AnimePicturesBuilder extends BaseBooruBuilder {
  AnimePicturesBuilder();

  @override
  late final postPresentation =
      TypedBooruPostPresentation<AnimePicturesPostData>(
        typeKey: 'anime_pictures',
        uiBuilder: postDetailsUIBuilder,
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
        child: CreateAnimePicturesConfigPage(
          backgroundColor: backgroundColor,
        ),
      );

  @override
  UpdateConfigPageBuilder get updateConfigPageBuilder =>
      (
        context,
        id, {
        backgroundColor,
        initialTab,
      }) => UpdateBooruConfigScope(
        id: id,
        child: CreateAnimePicturesConfigPage(
          backgroundColor: backgroundColor,
          initialTab: initialTab,
        ),
      );

  @override
  PostDetailsPageBuilder get postDetailsPageBuilder =>
      (context, payload) => MixedPostDetailsPageAdapter(
        payload: payload,
      );

  @override
  HomePageBuilder get homePageBuilder =>
      (context) => const AnimePicturesHomePage();

  @override
  FavoritesPageBuilder? get favoritesPageBuilder =>
      (context) => const AnimePicturesCurrentUserIdScope(
        child: AnimePicturesFavoritesPage(),
      );

  @override
  final postDetailsUIBuilder = PostDetailsUIBuilder(
    preview: {
      DetailsPart.toolbar: (context) =>
          const DefaultInheritedPostActionToolbar<Post>(),
    },
    full: {
      DetailsPart.toolbar: (context) =>
          const DefaultInheritedPostActionToolbar<Post>(),
      DetailsPart.tags: (context) => const DefaultInheritedTagsTile<Post>(),
      DetailsPart.fileDetails: (context) =>
          const DefaultInheritedFileDetailsSection<Post>(),
      DetailsPart.relatedPosts: (context) =>
          const AnimePicturesRelatedPostsSection(),
    },
  );
}
