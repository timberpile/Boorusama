// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/tags/favorites/providers.dart';
import 'package:boorusama/core/tags/favorites/src/providers/local_providers.dart';
import 'package:boorusama/core/tags/favorites/types.dart';

class InMemoryFavoriteTagRepository implements FavoriteTagRepository {
  InMemoryFavoriteTagRepository([List<FavoriteTag>? tags]) : _tags = [...?tags];

  final List<FavoriteTag> _tags;

  @override
  Future<FavoriteTag> create({
    required String name,
    List<String>? labels,
    QueryType? queryType,
  }) async {
    final now = DateTime.now();
    final tag = FavoriteTag(
      name: name,
      createdAt: now,
      updatedAt: now,
      labels: labels,
      queryType: queryType,
    );
    _tags.add(tag);
    return tag;
  }

  @override
  Future<FavoriteTag?> restore(FavoriteTag tag) async {
    if (_tags.any((existing) => existing.name == tag.name)) return null;
    _tags.add(tag);
    return tag;
  }

  @override
  Future<List<FavoriteTag>> createFrom(List<FavoriteTag> tags) async {
    _tags.addAll(tags);
    return tags;
  }

  @override
  Future<void> replaceAll(List<FavoriteTag> tags) async {
    _tags
      ..clear()
      ..addAll(tags);
  }

  @override
  Future<FavoriteTag?> deleteFirst(String name) async {
    final index = _tags.indexWhere((tag) => tag.name == name);
    if (index == -1) return null;
    return _tags.removeAt(index);
  }

  @override
  Future<List<FavoriteTag>> get(String name) async =>
      _tags.where((tag) => tag.name == name).toList();

  @override
  Future<List<FavoriteTag>> getAll() async => [..._tags];

  @override
  Future<FavoriteTag?> getFirst(String name) async {
    for (final tag in _tags) {
      if (tag.name == name) return tag;
    }
    return null;
  }

  @override
  Future<FavoriteTag?> updateFirst(String name, FavoriteTag tag) async {
    final index = _tags.indexWhere((item) => item.name == name);
    if (index == -1) return null;
    _tags[index] = tag.copyWith(updatedAt: DateTime.now);
    return _tags[index];
  }
}

void main() {
  late InMemoryFavoriteTagRepository repository;
  late ProviderContainer container;
  late FavoriteTagsNotifier notifier;

  setUp(() async {
    repository = InMemoryFavoriteTagRepository();
    container = ProviderContainer(
      overrides: [
        favoriteTagRepoProvider.overrideWith((ref) => repository),
      ],
    );
    addTearDown(container.dispose);
    notifier = container.read(favoriteTagsProvider.notifier);
    await notifier.load();
  });

  test('adds a raw query without changing its exact value', () async {
    const query = '(thighhighs ~ pantyhose) score:>=50';

    final added = await notifier.add(
      query,
      labels: ['daily'],
      isRaw: true,
    );

    expect(added, isTrue);
    expect(container.read(favoriteTagsProvider).single.name, query);
    expect(
      container.read(favoriteTagsProvider).single.queryType,
      QueryType.simple,
    );
    expect(container.read(favoriteTagsProvider).single.labels, ['daily']);
  });

  test('editing can change the exact value and query type', () async {
    await notifier.add('old_tag');
    final original = container.read(favoriteTagsProvider).single;

    final updated = await notifier.update(
      original.name,
      original.copyWith(
        name: 'rating:safe order:score',
        queryType: () => QueryType.simple,
      ),
    );

    expect(updated, isTrue);
    expect(
      container.read(favoriteTagsProvider).single.name,
      'rating:safe order:score',
    );
    expect(
      container.read(favoriteTagsProvider).single.queryType,
      QueryType.simple,
    );
    expect(await repository.getFirst('old_tag'), isNull);
  });

  test('editing rejects a duplicate value', () async {
    await notifier.add('first');
    await notifier.add('second');
    final second = container
        .read(favoriteTagsProvider)
        .firstWhere((tag) => tag.name == 'second');

    final updated = await notifier.update(
      second.name,
      second.copyWith(name: 'first'),
    );

    expect(updated, isFalse);
    expect(container.read(favoriteTagsProvider).map((tag) => tag.name), [
      'first',
      'second',
    ]);
  });

  test('undo restores the exact deleted favorite', () async {
    final original = FavoriteTag(
      name: 'archived',
      createdAt: DateTime.utc(2020),
      updatedAt: DateTime.utc(2021),
      labels: const ['daily'],
      queryType: QueryType.simple,
    );
    await repository.restore(original);
    await notifier.load();

    final deleted = await notifier.remove(original.name);
    final restored = await notifier.restore(deleted!);

    expect(restored, isTrue);
    expect(await repository.getFirst(original.name), original);
  });

  test('undo does not overwrite a replacement with the same name', () async {
    await notifier.add('archived', labels: ['old']);
    final deleted = await notifier.remove('archived');
    await notifier.add('archived', labels: ['replacement']);
    final replacement = await repository.getFirst('archived');

    final restored = await notifier.restore(deleted!);

    expect(restored, isFalse);
    expect(await repository.getFirst('archived'), replacement);
  });

  test('selected label resets when that label no longer exists', () async {
    final selection = container.listen(
      selectedFavoriteTagLabelProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(selection.close);
    await notifier.add('first', labels: ['daily']);
    container.read(selectedFavoriteTagLabelProvider.notifier).select('daily');

    await notifier.renameLabel('daily', 'archive');

    expect(container.read(selectedFavoriteTagLabelProvider), isEmpty);
  });

  test(
    'renaming a label updates every favorite and de-duplicates labels',
    () async {
      await notifier.add('first', labels: ['daily', 'wallpapers']);
      await notifier.add('second', labels: ['daily']);

      await notifier.renameLabel('daily', 'wallpapers');

      final tags = container.read(favoriteTagsProvider);
      expect(tags[0].labels, ['wallpapers']);
      expect(tags[1].labels, ['wallpapers']);
    },
  );

  test('merging and removing labels never deletes favorites', () async {
    await notifier.add('first', labels: ['daily']);
    await notifier.add('second', labels: ['reference']);

    await notifier.mergeLabel('daily', 'reference');
    await notifier.removeLabelFromAll('reference');

    final tags = container.read(favoriteTagsProvider);
    expect(tags, hasLength(2));
    expect(tags.every((tag) => tag.labels == null), isTrue);
  });
}
