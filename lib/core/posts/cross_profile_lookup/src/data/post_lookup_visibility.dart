import '../../../../configs/config/types.dart';
import '../../../../boorus/booru/types.dart';
import '../../../filter/types.dart';
import '../../../post/types.dart';
import '../../../rating/types.dart';

bool isExactLookupPostVisible(
  Post post,
  BooruConfig target,
  Set<String> blacklist,
) {
  final filter = target.search.filter;
  if (post.isFlash ||
      (filter.deletedItemBehavior.isHidden &&
          (post.status?.matches('deleted') ?? false)) ||
      (filter.bannedPostVisibility.isHidden &&
          (post.status?.matches('banned') ?? false))) {
    return false;
  }
  final visibleRating = switch (filter.ratingFilter) {
    BooruConfigRatingFilter.none => true,
    BooruConfigRatingFilter.hideNSFW => post.rating == Rating.general,
    BooruConfigRatingFilter.hideExplicit =>
      target.auth.booruType == BooruType.danbooru
          ? post.rating == Rating.general || post.rating == Rating.sensitive
          : post.rating != Rating.explicit && post.rating != Rating.unknown,
    BooruConfigRatingFilter.custom =>
      !(filter.granularRatingFilters?.ratings.contains(post.rating) ?? false),
  };
  return visibleRating && filterTags([post], blacklist).isNotEmpty;
}
