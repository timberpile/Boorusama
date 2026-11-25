import 'package:booru_clients/moebooru.dart';
import 'package:flutter/foundation.dart';

import '../../../core/tags/categories/src/tag_category.dart';
import '../../../core/tags/tag/src/types/tag_value.dart';
import '../tag_summary/parser.dart';
import '../tag_summary/types.dart';

/// Large summaries are processed in an isolate on native platforms.
Future<Map<String, Tag>> buildMoebooruTagMap(TagSummaryDto data) =>
    compute(_parseTagMap, data);

Map<String, Tag> _parseTagMap(TagSummaryDto data) => {
  for (final summary in convertTagSummaryDtoToTagSummaryList(data))
    summary.name: tagSummaryToTag(summary),
};

Tag tagSummaryToTag(TagSummary tagSummary) => Tag.noCount(
  name: tagSummary.name,
  category: TagCategory.fromLegacyId(tagSummary.category),
);
