// Project imports:
import '../../../home/types.dart';
import '../../../posts/details_parts/types.dart';
import '../../../posts/post/types.dart';
import 'booru_builder_types.dart';

abstract class BooruBuilder {
  BooruPostPresentation get postPresentation => const GenericPostPresentation();
  PostToUnifiedConverter? get postConverter => null;

  HomePageBuilder get homePageBuilder;
  CreateConfigPageBuilder get createConfigPageBuilder;
  UpdateConfigPageBuilder get updateConfigPageBuilder;
  SearchPageBuilder get searchPageBuilder;
  PostDetailsPageBuilder get postDetailsPageBuilder;
  FavoritesPageBuilder? get favoritesPageBuilder;
  ArtistPageBuilder? get artistPageBuilder;
  CharacterPageBuilder? get characterPageBuilder;
  CommentPageBuilder? get commentPageBuilder;
  QuickFavoriteButtonBuilder? get quickFavoriteButtonBuilder;
  HomeViewBuilder get homeViewBuilder;
  PostStatisticsPageBuilder get postStatisticsPageBuilder;
  TagSuggestionItemBuilder get tagSuggestionItemBuilder;
  MultiSelectionActionsBuilder? get multiSelectionActionsBuilder;
  Map<CustomHomeViewKey, CustomHomeDataBuilder> get customHomeViewBuilders;
  PostDetailsUIBuilder get postDetailsUIBuilder;
  ViewTagListBuilder get viewTagListBuilder;
  CreateUnknownBooruWidgetsBuilder get unknownBooruWidgetsBuilder;
  VideoQualitySelectionBuilder? get videoQualitySelectionBuilder;
  SessionRestoreBuilder? get sessionRestoreBuilder;
}
