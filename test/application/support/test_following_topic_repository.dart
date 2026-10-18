import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_hive_object.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart';
import 'package:boorusama/core/search/following_topics/src/data/providers.dart';
import 'package:boorusama/core/search/following_topics/src/types/following_topic_repository.dart';
import 'package:hive_ce/hive.dart';

final class TestFollowingTopicRepositoryNotifier
    extends FollowingTopicRepositoryNotifier {
  @override
  Future<FollowingTopicRepository> build() async =>
      HiveFollowingTopicRepository(
        box: _MemoryBox<FollowingTopicHiveObject>(),
        organizationBox: _MemoryBox<dynamic>(),
      );
}

final class _MemoryBox<T> implements Box<T> {
  final _items = <dynamic, T>{};

  @override
  Iterable<T> get values => _items.values;

  @override
  T? get(dynamic key, {T? defaultValue}) => _items[key] ?? defaultValue;

  @override
  bool containsKey(dynamic key) => _items.containsKey(key);

  @override
  Future<void> put(dynamic key, T value) async => _items[key] = value;

  @override
  Future<void> putAll(Map<dynamic, T> entries) async => _items.addAll(entries);

  @override
  Future<void> delete(dynamic key) async => _items.remove(key);

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    for (final key in keys) {
      _items.remove(key);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
