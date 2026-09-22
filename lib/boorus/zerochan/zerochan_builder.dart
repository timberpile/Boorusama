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

class ZerochanBuilder extends BaseBooruBuilder {
  ZerochanBuilder();

  @override
  late final postPresentation = TypedBooruPostPresentation<EmptyPostData>(
    typeKey: 'zerochan',
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
  PostDetailsPageBuilder get postDetailsPageBuilder =>
      (context, payload) => LegacyPostDetailsPageAdapter(
        payload: payload,
        converter: (post, origin) =>
            zerochanPostToUnified(post as ZerochanPost, origin),
      );

  @override
  final postDetailsUIBuilder = kZerochanPostDetailsUIBuilder;
}
