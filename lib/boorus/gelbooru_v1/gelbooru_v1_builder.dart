// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../core/boorus/defaults/widgets.dart';
import '../../core/boorus/engine/types.dart';
import '../../core/configs/config/providers.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/widgets.dart';
import '../../core/configs/manage/widgets.dart';
import '../../core/downloads/filename/types.dart';
import '../../core/posts/details/widgets.dart';
import '../../core/posts/details_parts/types.dart';
import '../../core/posts/post/types.dart';
import '../../core/posts/post/providers.dart';
import '../../core/search/search/routes.dart';
import '../../core/search/search/widgets.dart';
import '../../foundation/html.dart';
import 'configs/widgets.dart';

class GelbooruV1Builder extends BaseBooruBuilder {
  GelbooruV1Builder();

  @override
  late final postPresentation = TypedBooruPostPresentation<EmptyPostData>(
    typeKey: 'gelbooru_v1',
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
          customDownloadFileNameFormat: kDefaultCustomDownloadFileNameFormat,
        ),
        child: CreateGelbooruV1ConfigPage(
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
        child: CreateGelbooruV1ConfigPage(
          backgroundColor: backgroundColor,
          initialTab: initialTab,
        ),
      );

  @override
  SearchPageBuilder get searchPageBuilder =>
      (context, params) => GelbooruV1SearchPage(
        params: params,
      );

  @override
  final PostDetailsUIBuilder postDetailsUIBuilder =
      kFallbackPostDetailsUIBuilder;

  @override
  PostDetailsPageBuilder get postDetailsPageBuilder =>
      (context, payload) => MixedPostDetailsPageAdapter(
        payload: payload,
      );

  @override
  CreateUnknownBooruWidgetsBuilder get unknownBooruWidgetsBuilder =>
      (context) => const AnonUnknownBooruWidgets();
}

class GelbooruV1SearchPage extends ConsumerWidget {
  const GelbooruV1SearchPage({
    required this.params,
    super.key,
  });

  final SearchParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postRepo = ref.watch(originAwarePostRepoProvider(ref.watchConfig));

    return SearchPageScaffold(
      landingViewBuilder: (controller) => DefaultMobileSearchLandingView(
        notice: KurumiInfoContainer(
          contentBuilder: (context) => const AppHtml(
            data: 'The app will use <b>Gelbooru</b> for tag completion.',
          ),
        ),
        controller: controller,
      ),
      params: params,
      fetcher: (page, controller) => postRepo.getPostsFromController(
        controller.tagSet,
        page,
      ),
    );
  }
}
