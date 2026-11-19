class PoolDto {
  PoolDto({
    this.id,
    this.name,
    this.createdAt,
    this.updatedAt,
    this.description,
    this.isActive,
    this.isDeleted,
    this.postIds,
    this.category,
    this.postCount,
  });

  factory PoolDto.fromJson(Map<String, dynamic> json) => PoolDto(
    id: json['id'],
    name: json['name'],
    createdAt: json['created_at'] == null
        ? null
        : DateTime.tryParse(json['created_at'].toString()),
    updatedAt: json['updated_at'] == null
        ? null
        : DateTime.tryParse(json['updated_at'].toString()),
    description: json['description'],
    isActive: json['is_active'],
    isDeleted: json['is_deleted'],
    postIds: switch (json['post_ids']) {
      final List rows when rows.every((id) => id is int && id > 0) =>
        List<int>.from(rows),
      _ => null,
    },
    category: json['category'],
    postCount: switch (json['post_count']) {
      final int count when count >= 0 => count,
      _ => null,
    },
  );

  final int? id;
  final String? name;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? description;
  final bool? isActive;
  final bool? isDeleted;
  final List<int>? postIds;
  final String? category;
  final int? postCount;

  @override
  String toString() => name ?? '';
}
