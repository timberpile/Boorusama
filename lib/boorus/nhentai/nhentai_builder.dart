import '../../core/boorus/defaults/widgets.dart';
import '../../core/boorus/engine/types.dart';
import '../../core/posts/details/widgets.dart';
import '../../core/posts/post/types.dart';
import '../../core/search/search/routes.dart';
import 'posts/data.dart';
import 'search/page.dart';

class NhentaiBuilder extends BaseBooruBuilder {
  @override
  HomeViewBuilder get homeViewBuilder =>
      (context) => const NhentaiSearchPage(params: SearchParams());
  @override
  late final postPresentation = TypedBooruPostPresentation<NhentaiPostData>(
    typeKey: 'nhentai',
    uiBuilder: postDetailsUIBuilder,
  );
  @override
  SearchPageBuilder get searchPageBuilder =>
      (context, params) => NhentaiSearchPage(params: params);
  @override
  PostDetailsPageBuilder get postDetailsPageBuilder =>
      (context, payload) => MixedPostDetailsPageAdapter(payload: payload);
}
