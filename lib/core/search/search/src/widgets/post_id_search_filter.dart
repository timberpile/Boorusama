import '../../../options/search_option.dart';
import '../../../selected_tags/types.dart';
import '../../../../posts/listing/src/types/post_search_actions.dart';

export '../../../../posts/listing/src/types/post_search_actions.dart'
    show PostIdSearchDirection;

final _standaloneId = RegExp(
  r'^id:(?:[<>]=?\d+|\d+(?:\.\.\d*)?|\.\.\d+|\d+(?:,\d+)+)$|^id\.(?:gte|lte|gt|lt):\d+$',
);
final _embeddedId = RegExp(
  r'(?<![A-Za-z0-9_])(?:-)?id(?:\.(?:gte|lte|gt|lt))?:',
  caseSensitive: false,
);

/// Replace independent post-ID filters, retaining every other search condition.
/// Refuse nested/opaque ID expressions rather than altering their meaning.
List<TagSearchItem>? refinePostIdSearch({
  required List<TagSearchItem> tags,
  required SearchOption option,
  required int postId,
  required PostIdSearchDirection direction,
}) {
  if (postId <= 0 || option.kind != SearchOptionKind.postId) return null;
  final value = switch (direction) {
    PostIdSearchDirection.fromHere => '>=$postId',
    PostIdSearchDirection.untilHere => '<=$postId',
  };
  final predicate = option.compose(value);
  if (predicate == null) return null;

  final updated = <TagSearchItem>[];
  for (final item in tags) {
    final text = item.originalTag;
    if (!item.isRaw) {
      if (_standaloneId.hasMatch(text)) continue;
      if (_embeddedId.hasMatch(text)) return null;
      updated.add(item);
      continue;
    }
    // Whitespace alone does not establish whether an ID term belongs to a
    // grouped expression. Keep that opaque syntax intact rather than moving
    // its predicate outside the group or dropping a closing delimiter.
    if (_embeddedId.hasMatch(text) && RegExp(r'[()\[\]{}]').hasMatch(text)) {
      return null;
    }
    final tokens = text.trim().split(RegExp(r'\s+'));
    final retained = <String>[];
    for (final token in tokens) {
      if (_standaloneId.hasMatch(token)) continue;
      if (_embeddedId.hasMatch(token)) return null;
      if (token.isNotEmpty) retained.add(token);
    }
    if (retained.isNotEmpty) {
      updated.add(
        retained.length == tokens.length
            ? item
            : TagSearchItem.raw(tag: retained.join(' ')),
      );
    }
  }
  return [
    ...updated,
    TagSearchItem.fromString(predicate),
  ];
}
