// Project imports:
import '../../core/boorus/defaults/widgets.dart';
import '../../core/boorus/engine/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/widgets.dart';
import '../../core/configs/manage/widgets.dart';
import '../../core/home/types.dart';
import '../../core/posts/details/widgets.dart';
import '../../core/posts/details_parts/types.dart';
import '../../core/posts/details_parts/widgets.dart';
import '../../core/posts/post/types.dart';
import 'configs/widgets.dart';
import 'home/custom_home.dart';
import 'home/pixiv_home_page.dart';
import 'posts/post_codec.dart';
import 'posts/post_data.dart';
import 'posts/types.dart';

class PixivBuilder extends BaseBooruBuilder {
  PixivBuilder();

  @override
  late final postPresentation = TypedBooruPostPresentation<PixivPostData>(
    typeKey: 'pixiv',
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
  PostDetailsPageBuilder get postDetailsPageBuilder =>
      (context, payload) => LegacyPostDetailsPageAdapter(
        payload: payload,
        converter: (post, origin) =>
            pixivPostToUnified(post as PixivPost, origin),
      );

  /// Pixiv illusts carry a meaningful tag pool, so the tags section stays
  /// part of the details UI.
  @override
  final postDetailsUIBuilder = PostDetailsUIBuilder(
    preview: {
      DetailsPart.toolbar: (context) =>
          const DefaultInheritedPostActionToolbar<UnifiedPost>(),
    },
    full: {
      DetailsPart.toolbar: (context) =>
          const DefaultInheritedPostActionToolbar<UnifiedPost>(),
      DetailsPart.tags: (context) =>
          const DefaultInheritedTagsTile<UnifiedPost>(),
      DetailsPart.fileDetails: (context) =>
          const DefaultInheritedFileDetailsSection<UnifiedPost>(),
    },
  );

  @override
  Map<CustomHomeViewKey, CustomHomeDataBuilder> get customHomeViewBuilders =>
      pixivCustomHome;

  @override
  HomePageBuilder get homePageBuilder =>
      (context) => const PixivHomePage();
}
