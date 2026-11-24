import '../../configs/config/types.dart';
import '../../posts/filter/types.dart';
import '../../posts/rating/types.dart';
import 'group_metadata.dart';

/// Group-level observations are matched without fabricating a representative
/// Post. Unknown membership cannot prove a blacklisted tag is absent.
bool groupTagsPassBlacklist(
  GroupTags? tags,
  Set<String> blacklist, {
  required Rating rating,
  int? sourceId,
  String? sourceUrl,
}) {
  if (blacklist.isEmpty) return true;
  if (tags == null || tags.coverage != MetadataCoverage.complete) return false;
  final names = <String>{};
  for (final tag in tags.values) {
    final name = tag.name;
    if (name == null) return false;
    final canonical = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    names.add(canonical);
    if (tag.category case final category?) names.add('$category:$canonical');
    if (tag.displayName case final translated?) {
      names.add(translated.toLowerCase().replaceAll(RegExp(r'\s+'), '_'));
    }
  }
  final facts = TagFilterData(
    tags: names,
    rating: rating,
    score: 0,
    id: sourceId,
    source: sourceUrl?.toLowerCase(),
  );
  return !blacklist.any(
    (pattern) => checkIfTagsContainsRawTagExpression(facts, pattern),
  );
}

bool groupAllowsRating(BooruConfig config, Rating rating) =>
    switch (config.ratingFilter) {
      BooruConfigRatingFilter.none => true,
      BooruConfigRatingFilter.hideExplicit =>
        rating != Rating.explicit && rating != Rating.unknown,
      BooruConfigRatingFilter.hideNSFW =>
        rating == Rating.general || rating == Rating.sensitive,
      BooruConfigRatingFilter.custom =>
        config.granularRatingFilters?.ratings.contains(rating) ?? false,
    };

/// Cover tags describe one selected Post. Never substitute a site URL or zero
/// score for facts needed by a newly applied blacklist expression.
bool groupCoverPassesBlacklist(
  GroupCoverVisibility facts,
  Set<String> blacklist, {
  int? postId,
}) {
  if (facts.tagCoverage != MetadataCoverage.complete) return false;
  final extra = facts.postFacts;
  final factExpressions = RegExp(
    r'(?:^|\s)[~-]?(source|score|downvotes|uploader|uploaderid):',
    caseSensitive: false,
  );
  // Status implementations are engine-specific; deleted/banned flags do not
  // prove arbitrary status expressions such as pending or flagged.
  if (blacklist.any(
    (p) => RegExp(r'(?:^|\s)[~-]?status:', caseSensitive: false).hasMatch(p),
  )) {
    return false;
  }
  if (extra == null && blacklist.any(factExpressions.hasMatch)) return false;
  final data = TagFilterData(
    tags: facts.tags.map((v) => v.toLowerCase()).toSet(),
    rating: Rating.parse(facts.rating),
    score: extra?['score'] as int? ?? 0,
    downvotes: extra?['downvotes'] as int?,
    uploaderId: extra?['uploaderId'] as int?,
    uploaderName: extra?['uploaderName'] as String?,
    source: extra?['source'] as String?,
    id: postId,
  );
  return !blacklist.any(
    (pattern) => checkIfTagsContainsRawTagExpression(data, pattern),
  );
}
