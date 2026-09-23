// Project imports:
import '../../core/boorus/defaults/widgets.dart';
import '../../core/boorus/engine/types.dart';
import '../../core/configs/auth/widgets.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/widgets.dart';
import '../../core/configs/manage/widgets.dart';
import '../../core/configs/network/widgets.dart';
import '../../core/posts/details/widgets.dart';
import '../../core/posts/post/types.dart';
import 'configs/widgets.dart';
import 'posts/post_data.dart';
import 'posts/types.dart';
import 'posts/widgets.dart';

class PhilomenaBuilder extends BaseBooruBuilder {
  PhilomenaBuilder();

  @override
  late final postPresentation = TypedBooruPostPresentation<PhilomenaPostData>(
    typeKey: 'philomena',
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
        child: CreatePhilomenaConfigPage(
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
        child: CreatePhilomenaConfigPage(
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
  final postDetailsUIBuilder = kPhilomenaPostDetailsUIBuilder;

  @override
  CreateUnknownBooruWidgetsBuilder get unknownBooruWidgetsBuilder =>
      (context) => const UnknownBooruWidgetsBuilder(
        httpProtocolField: HttpProtocolOptionTile(),
        apiKeyField: DefaultBooruApiKeyField(),
      );
}
