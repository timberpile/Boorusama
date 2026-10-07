import 'package:boorusama/core/posts/post/types.dart';

StoredPostSnapshot rehydrateSnapshotWithDynamicNestedMaps(
  StoredPostSnapshot snapshot,
) {
  final persisted = switch (_dynamicValue(snapshot.toJson())) {
    final Map<Object?, Object?> map => map,
    _ => throw StateError('Stored post snapshot must remain a map'),
  };
  return StoredPostSnapshot.fromJson(Map<String, dynamic>.from(persisted));
}

Object? _dynamicValue(Object? value) => switch (value) {
  final Map<Object?, Object?> map => <Object?, Object?>{
    for (final entry in map.entries) entry.key: _dynamicValue(entry.value),
  },
  final List<Object?> values => <Object?>[
    for (final value in values) _dynamicValue(value),
  ],
  _ => value,
};
