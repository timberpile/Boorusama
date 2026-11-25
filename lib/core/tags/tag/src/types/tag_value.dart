// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../categories/src/tag_category.dart';

typedef PostCount = int;

class Tag extends Equatable {
  const Tag({
    required this.name,
    required this.category,
    required this.postCount,
    this.label,
  });

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
    name: json['name'],
    category: TagCategory.fromLegacyId(json['category']),
    postCount: json['postCount'],
    label: json['label'] as String?,
  );

  const Tag.noCount({
    required this.name,
    required this.category,
    this.label,
  }) : postCount = 0;

  factory Tag.empty() => Tag(
    name: '',
    category: TagCategory.unknown(),
    postCount: 0,
  );

  Tag copyWith(
    String? name,
    TagCategory? category,
    PostCount? postCount, {
    String? label,
  }) => Tag(
    name: name ?? this.name,
    category: category ?? this.category,
    postCount: postCount ?? this.postCount,
    label: label ?? this.label,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category.id,
    'postCount': postCount,
    'label': ?label,
  };

  final String name;
  final String? label;
  final TagCategory category;
  final PostCount postCount;

  @override
  String toString() => '$name ($postCount)';

  @override
  List<Object?> get props => [name, label, category, postCount];
}
