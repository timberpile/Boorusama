import '../../../boorus/booru/types.dart';

/// Only complete synonyms verified against each engine's search parser belong
/// here. Similar labels or overlapping predicates do not establish equivalence.
Map<String, String> searchOptionAliasesFor(BooruType type) => switch (type) {
  // Danbooru PostQueryBuilder::COUNT_METATAGS and Post#metatag_matches.
  // Prefer explicit field names over shorthand and plural count synonyms.
  BooruType.danbooru => const {
    'pixiv': 'pixiv_id',
    'comm': 'commenter',
    'artcomm': 'commentaryupdater',
    'comments': 'comment_count',
    'deleted_comments': 'deleted_comment_count',
    'active_comments': 'active_comment_count',
    'notes': 'note_count',
    'deleted_notes': 'deleted_note_count',
    'active_notes': 'active_note_count',
    'flags': 'flag_count',
    'children': 'child_count',
    'deleted_children': 'deleted_child_count',
    'active_children': 'active_child_count',
    'pools': 'pool_count',
    'deleted_pools': 'deleted_pool_count',
    'active_pools': 'active_pool_count',
    'series_pools': 'series_pool_count',
    'collection_pools': 'collection_pool_count',
    'appeals': 'appeal_count',
    'approvals': 'approval_count',
    'replacements': 'replacement_count',
    'disapprovals': 'disapproval_count',
  },
  // e621 TagQuery#scan_query and BOOLEAN_METATAG_ALIASES.
  BooruType.e621 => const {
    'type': 'filetype',
    'comm': 'commenter',
    'favoritedby': 'fav',
    'flaggedby': 'flagger',
    'votedup': 'upvote',
    'upvoted': 'upvote',
    'voteup': 'upvote',
    'voteddown': 'downvote',
    'downvoted': 'downvote',
    'votedown': 'downvote',
    'vote': 'voted',
    'hasparent': 'ischild',
    'haschild': 'isparent',
    'haschildren': 'isparent',
  },
  _ => const {},
};
