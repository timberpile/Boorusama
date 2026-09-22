// Project imports:
import '../../core/boorus/defaults/widgets.dart';
import '../../core/boorus/engine/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/widgets.dart';
import '../../core/posts/details/widgets.dart';
import '../../core/posts/post/types.dart';
import 'posts/post_codec.dart';
import 'posts/types.dart';
import 'posts/widgets.dart';
import 'search/widgets.dart';

class NozomiBuilder extends BaseBooruBuilder {
  NozomiBuilder();

  @override
  late final postPresentation = TypedBooruPostPresentation<EmptyPostData>(
    typeKey: 'nozomi',
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
        child: CreateAnonConfigPage(
          backgroundColor: backgroundColor,
        ),
      );

  @override
  SearchPageBuilder get searchPageBuilder =>
      (context, params) => NozomiSearchPage(
        params: params,
      );

  @override
  PostDetailsPageBuilder get postDetailsPageBuilder =>
      (context, payload) => LegacyPostDetailsPageAdapter(
        payload: payload,
        converter: (post, origin) =>
            nozomiPostToUnified(post as NozomiPost, origin),
      );

  @override
  final postDetailsUIBuilder = kNozomiPostDetailsUIBuilder;
}
