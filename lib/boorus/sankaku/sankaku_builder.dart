// Project imports:
import '../../core/boorus/defaults/widgets.dart';
import '../../core/boorus/engine/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/config/providers.dart';
import '../../core/configs/create/widgets.dart';
import '../../core/configs/manage/widgets.dart';
import '../../core/downloads/filename/types.dart';
import '../../core/posts/details/widgets.dart';
import '../../core/posts/post/types.dart';
import 'artists/widgets.dart';
import 'configs/widgets.dart';
import 'favorites/widgets.dart';
import 'favorites/providers.dart';
import 'posts/post_data.dart';
import 'posts/types.dart';
import 'posts/widgets.dart';

class SankakuBuilder extends BaseBooruBuilder {
  SankakuBuilder();

  @override
  late final postPresentation = TypedBooruPostPresentation<SankakuPostData>(
    typeKey: 'sankaku',
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
          customDownloadFileNameFormat: kBoorusamaCustomDownloadFileNameFormat,
        ),
        child: CreateSankakuConfigPage(
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
        child: CreateSankakuConfigPage(
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
  ArtistPageBuilder? get artistPageBuilder =>
      (context, artistName) => SankakuArtistPage(
        artistName: artistName,
      );

  @override
  FavoritesPageBuilder? get favoritesPageBuilder =>
      (context) => const SankakuFavoritesPage();

  @override
  QuickFavoriteButtonBuilder get quickFavoriteButtonBuilder =>
      (context, ref, post) =>
          post.sankakuData?.sankakuId != null &&
              ref.watch(sankakuCanFavoriteProvider(ref.watchConfigAuth))
          ? SankakuQuickFavoriteButton(post: post)
          : null;

  @override
  final postDetailsUIBuilder = kSankakuPostDetailsUIBuilder;
}
