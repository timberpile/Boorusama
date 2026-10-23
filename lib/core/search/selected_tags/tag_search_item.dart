// Package imports:
import 'package:equatable/equatable.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import '../../tags/metatag/types.dart';
import '../queries/types.dart';

class TagSearchItem extends Equatable {
  const TagSearchItem._({
    required this.tag,
    required this.operator,
    required this.originalTag,
    required this.isRaw,
    this.metatag,
    this.category,
  });

  const TagSearchItem.raw({
    required this.tag,
  }) : operator = FilterOperator.none,
       isRaw = true,
       originalTag = tag,
       category = null,
       metatag = null;

  factory TagSearchItem.fromString(
    String query, {
    MetatagExtractor? extractor,
    String? category,
  }) {
    final metatag = extractor?.fromString(query);
    final operator = FilterOperator.fromString(query.getFirstCharacter());
    final tag = stripFilterOperator(query, operator);

    if (metatag == null) {
      return TagSearchItem._(
        tag: tag.replaceAll('_', ' '),
        operator: operator,
        originalTag: query,
        isRaw: false,
        category: category,
      );
    }

    return TagSearchItem._(
      tag: tag.replaceAll('$metatag:', '').replaceAll('_', ' '),
      operator: operator,
      metatag: metatag,
      originalTag: query,
      isRaw: false,
      category: category,
    );
  }

  final String originalTag;
  final String tag;
  final FilterOperator operator;
  final String? metatag;
  final bool isRaw;
  final String? category;

  TagSearchItem withQuery(
    String query, {
    MetatagExtractor? extractor,
  }) {
    if (isRaw) return TagSearchItem.raw(tag: query);
    final updated = TagSearchItem.fromString(query, extractor: extractor);
    return TagSearchItem._(
      tag: updated.tag,
      operator: updated.operator,
      originalTag: updated.originalTag,
      isRaw: false,
      metatag: updated.metatag,
      // Changing an operator does not change a tag's category; renaming the
      // tag does. Do not carry autocomplete metadata onto an unrelated tag.
      category: updated.rawTag == rawTag && updated.metatag == metatag
          ? category
          : null,
    );
  }

  // This assume no whitespace in the tag, which is true for most boorus
  String get rawTag => tag.replaceAll(' ', '_');

  // Category metadata does not affect search-term identity.
  @override
  List<Object?> get props => [
    tag,
    operator,
    metatag,
    isRaw,
    originalTag,
  ];

  @override
  String toString() => isRaw
      ? tag
      : '$operator${metatag ?? ''}${metatag != null ? ':' : ''}$tag'.replaceAll(
          ' ',
          '_',
        );
}
