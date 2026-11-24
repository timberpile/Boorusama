import 'package:booru_clients/danbooru.dart';

import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/posts/filter/types.dart';
import '../../../../posts/post/src/converter.dart';
import 'danbooru_pool.dart';
import 'pool_cover.dart';

enum PoolAvailability { accessible, provenEmpty, unknown }

enum PoolMemberEvidence { accessible, denied, unknown }

bool isDonmaiSafebooru(String url) =>
    Uri.tryParse(url)?.host.toLowerCase() == 'safebooru.donmai.us';

List<int> poolAvailabilityCandidates(DanbooruPool pool) {
  final ids = pool.postIds;
  if (ids == null || ids.isEmpty || ids.any((id) => id <= 0)) return const [];
  final distinct = ids.toSet().toList();
  return distinct.length <= 3
      ? distinct.reversed.toList()
      : [distinct.last, distinct[distinct.length ~/ 2], distinct.first];
}

/// Converter defaults are deliberately downstream of the presence checks.
PoolMemberEvidence safebooruMemberEvidence(
  PostDto dto,
  BooruConfigSearch config,
  Set<String>? blacklist,
) {
  if (dto.id == null || dto.id! <= 0) return PoolMemberEvidence.unknown;
  if (const {'s', 'q', 'e'}.contains(dto.rating)) {
    return PoolMemberEvidence.denied;
  }
  final filter = config.filter;
  if ((filter.deletedItemBehavior.isHidden && (dto.isDeleted ?? false)) ||
      (filter.bannedPostVisibility.isHidden && (dto.isBanned ?? false)) ||
      const {'swf', '.swf'}.contains(dto.fileExt?.toLowerCase())) {
    return PoolMemberEvidence.denied;
  }
  if (dto.tagString != null &&
      blacklist != null &&
      filterTags([postDtoToPost(dto, null)], blacklist).isEmpty) {
    return PoolMemberEvidence.denied;
  }
  if (dto.rating != 'g' ||
      dto.fileExt == null ||
      dto.tagString == null ||
      blacklist == null ||
      (filter.deletedItemBehavior.isHidden && dto.isDeleted == null) ||
      (filter.bannedPostVisibility.isHidden && dto.isBanned == null)) {
    return PoolMemberEvidence.unknown;
  }
  if (filter.ratingFilter == BooruConfigRatingFilter.custom &&
      (filter.granularRatingFilters?.ratings.any((r) => r.name == 'general') ??
          false)) {
    return PoolMemberEvidence.denied;
  }
  return PoolMemberEvidence.accessible;
}

class PoolAssessment {
  const PoolAssessment({
    required this.availability,
    this.accessibleCount,
    this.covers = const [],
  });
  final PoolAvailability availability;
  final int? accessibleCount;
  final List<PoolCover> covers;
}

PoolAssessment assessSafebooruPool(
  DanbooruPool pool,
  Map<int, PostDto> posts,
  BooruConfigSearch config,
  Set<String>? blacklist,
) {
  final manifest = pool.postIds;
  final complete =
      pool.manifestComplete &&
      manifest != null &&
      manifest.every((id) => id > 0);
  final evidence = <int, PoolMemberEvidence>{
    for (final id in manifest ?? const <int>[])
      id: posts[id] == null
          ? PoolMemberEvidence.unknown
          : safebooruMemberEvidence(posts[id]!, config, blacklist),
  };
  final accessible = evidence.values
      .where((e) => e == PoolMemberEvidence.accessible)
      .length;
  final allKnown =
      complete && evidence.values.every((e) => e != PoolMemberEvidence.unknown);
  final covers = <PoolCover>[];
  for (final id in poolAvailabilityCandidates(pool)) {
    if (evidence[id] != PoolMemberEvidence.accessible) continue;
    final post = postDtoToPost(posts[id]!, null);
    final candidate = PoolCover.fromPost(post);
    final uri = Uri.tryParse(candidate.url ?? '');
    if (uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        RegExp(
          r'\.(jpg|jpeg|png|webp|avif)$',
          caseSensitive: false,
        ).hasMatch(uri.path)) {
      covers.add(candidate);
    }
  }
  return PoolAssessment(
    availability: accessible > 0
        ? PoolAvailability.accessible
        : allKnown
        ? PoolAvailability.provenEmpty
        : PoolAvailability.unknown,
    accessibleCount: allKnown ? accessible : null,
    covers: List.unmodifiable(covers),
  );
}
