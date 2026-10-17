import 'dart:io';

import 'package:boorusama/boorus/danbooru/tags/user_metatags/src/data/factory.dart';
import 'package:boorusama/boorus/danbooru/tags/user_metatags/src/providers.dart';
import 'package:boorusama/boorus/danbooru/tags/user_metatags/src/user_metatag_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory root;
  const factory = HiveDanbooruUserMetatagRepositoryFactory();
  setUp(() async {
    root = await Directory.systemTemp.createTemp('user-metatags-');
    Hive.init(root.path);
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  test(
    'first use seeds defaults, intentionally empty saved list stays empty',
    () async {
      final first = await factory.create();
      expect(
        first.getAll(),
        unorderedEquals(['age', 'rating', 'order', 'score', 'id', 'user']),
      );
      for (final tag in first.getAll()) {
        await first.delete(tag);
      }
      expect(first.getAll(), isEmpty);
      await factory.dispose(first);
      await first.box.close();
      final reopened = await factory.create();
      expect(reopened.getAll(), isEmpty);
      await factory.dispose(reopened);
      await reopened.box.close();
    },
  );

  test(
    'custom partial list survives a cold reopen without added defaults',
    () async {
      final first = await factory.create();
      for (final tag in first.getAll()) {
        await first.delete(tag);
      }
      await first.put('rating');
      await first.put('user');
      await factory.dispose(first);
      await first.box.close();
      final reopened = await factory.create();
      expect(reopened.getAll(), ['rating', 'user']);
      await factory.dispose(reopened);
      await reopened.box.close();
    },
  );

  test(
    'replacement metatag scope can read, write and delete after old disposal',
    () async {
      final observedFactory = _ObservedMetatagFactory();
      ProviderContainer scope() => ProviderContainer(
        overrides: [
          danbooruUserMetatagRepositoryFactoryProvider.overrideWithValue(
            observedFactory,
          ),
        ],
      );
      final oldScope = scope();
      ProviderContainer? replacementScope;
      var oldDisposed = false;
      try {
        final oldRepository = await oldScope.read(
          danbooruUserMetatagRepoProvider.future,
        );
        await oldRepository.put('height');
        replacementScope = scope();
        final replacement = await replacementScope.read(
          danbooruUserMetatagRepoProvider.future,
        );
        expect(replacement.getAll(), contains('height'));

        oldScope.dispose();
        oldDisposed = true;
        await observedFactory.disposals.single;
        expect(replacement.getAll(), contains('height'));
        await replacement.put('width');
        expect(replacement.getAll(), contains('width'));
        await replacement.delete('height');
        expect(replacement.getAll(), isNot(contains('height')));
        expect(replacement.getAll(), contains('width'));
      } finally {
        if (!oldDisposed) oldScope.dispose();
        replacementScope?.dispose();
        await Future.wait(
          observedFactory.disposals.map(
            (future) => future.catchError((Object _) {}),
          ),
        );
      }
    },
  );
}

// Observe completion of production disposal without replacing its ownership policy.
class _ObservedMetatagFactory implements DanbooruUserMetatagRepositoryFactory {
  final production = const HiveDanbooruUserMetatagRepositoryFactory();
  final disposals = <Future<void>>[];

  @override
  Future<UserMetatagRepository> create() => production.create();

  @override
  Future<void> dispose(UserMetatagRepository repository) {
    final completion = production.dispose(repository);
    disposals.add(completion);
    return completion;
  }
}
