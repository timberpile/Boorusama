import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late DefaultImageCacheManager manager;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('image-policy-');
    manager = DefaultImageCacheManager(cacheRootPathProvider: () => root.path);
  });
  tearDown(() async {
    await manager.dispose();
    await root.delete(recursive: true);
  });

  Future<void> limit(int value) => manager.setMaxBytes(value);
  Future<void> save(String key, int length) => manager.saveFile(
    key,
    Uint8List.fromList(List.filled(length, key.codeUnitAt(0))),
  );

  test(
    'images with identical paths on different hosts keep independent bytes',
    () async {
      final firstKey = manager.generateCacheKey(
        'https://a.example.test/favicon.ico',
      );
      final secondKey = manager.generateCacheKey(
        'https://b.example.test/favicon.ico',
      );

      expect(firstKey, isNot(secondKey));
      await manager.saveFile(firstKey, Uint8List.fromList([1, 2]));
      await manager.saveFile(secondKey, Uint8List.fromList([3, 4]));

      expect(await manager.getCachedFileBytes(firstKey), [1, 2]);
      expect(await manager.getCachedFileBytes(secondKey), [3, 4]);
    },
  );

  test('cache keys distinguish schemes, ports and query parameters', () {
    const url = 'https://example.test/img.png?size=64';
    final key = manager.generateCacheKey(url);

    expect(
      key,
      isNot(manager.generateCacheKey('http://example.test/img.png?size=64')),
    );
    expect(
      key,
      isNot(
        manager.generateCacheKey(
          'https://example.test:8443/img.png?size=64',
        ),
      ),
    );
    expect(
      key,
      isNot(manager.generateCacheKey('https://example.test/img.png?size=128')),
    );
  });

  test('URL fragments do not affect the cache key', () {
    const url = 'https://example.test/img.png';
    final key = manager.generateCacheKey(url);

    expect(key, manager.generateCacheKey('$url#first'));
    expect(key, manager.generateCacheKey('$url#second'));
  });

  test('explicit custom keys still override URL-based cache keys', () {
    expect(
      manager.generateCacheKey(
        'https://example.test/img.png',
        customKey: 'shared',
      ),
      'shared',
    );
  });

  test(
    'evicts the least recently read file and keeps use order after restart',
    () async {
      await limit(8);
      await save('A', 4);
      await save('B', 4);
      expect(await manager.getCachedFileBytes('A'), [65, 65, 65, 65]);
      await manager.dispose();
      manager = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
      );
      await limit(8);
      await save('C', 4);
      expect(await manager.hasValidCache('B'), isFalse);
      expect(await manager.hasValidCache('A'), isTrue);
      expect(await manager.hasValidCache('C'), isTrue);
    },
  );

  test(
    'preserves A B A use order rather than download or probe order',
    () async {
      await limit(8);
      await save('A', 4);
      await save('B', 4);
      await manager.getCachedFileBytes('A');
      await manager.hasValidCache('B');
      await manager.getCachedFilePath('B');
      await manager.dispose();
      manager = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
      );
      await limit(8);
      await save('C', 4);
      expect(await manager.hasValidCache('B'), isFalse);
    },
  );

  test('an oversized candidate does not evict fitting files', () async {
    await limit(8);
    await save('A', 4);
    await save('B', 4);
    await save('C', 9);
    expect(await manager.hasValidCache('A'), isTrue);
    expect(await manager.hasValidCache('B'), isTrue);
    expect(await manager.hasValidCache('C'), isFalse);
  });

  test(
    'disabled file caching clears existing files and retains no new payload',
    () async {
      await save('A', 4);
      await limit(0);
      await save('B', 4);
      expect(await manager.hasValidCache('A'), isFalse);
      expect(await manager.hasValidCache('B'), isFalse);
      expect(
        await Directory('${root.path}/cacheimage').list().toList(),
        isEmpty,
      );
    },
  );

  test('concurrent commits share one capacity decision', () async {
    await limit(6);
    await Future.wait([save('A', 4), save('B', 4)]);
    final files = await Directory(
      '${root.path}/cacheimage',
    ).list().where((f) => f is File).cast<File>().toList();
    final lengths = await Future.wait(files.map((file) => file.length()));
    expect(lengths.fold<int>(0, (a, b) => a + b), lessThanOrEqualTo(6));
    expect(
      [
        await manager.hasValidCache('A'),
        await manager.hasValidCache('B'),
      ].where((b) => b),
      hasLength(1),
    );
  });

  test('ordinary cached files remain usable after more than a week', () async {
    await save('A', 4);
    final path = await manager.getCachedFilePath('A');
    await File(
      path!,
    ).setLastModified(DateTime.now().subtract(const Duration(days: 9)));
    expect(await manager.getCachedFileBytes('A'), [65, 65, 65, 65]);
  });

  test(
    'raw RAM hits update persistent use without retaining disabled admissions',
    () async {
      await manager.dispose();
      manager = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
        memoryCache: LRUMemoryCache(),
      );
      await limit(8);
      await save('A', 4);
      await save('B', 4);
      await manager.getCachedFileBytes('A');
      await save('C', 4);
      expect(await manager.hasValidCache('B'), isFalse);
      await limit(0);
      await save('D', 4);
      expect(await manager.getCachedFileBytes('D'), isNull);
    },
  );

  test(
    'reconciles missing files and corrupt metadata without changing unrelated files',
    () async {
      await limit(8);
      await save('A', 4);
      await save('B', 4);
      await File((await manager.getCachedFilePath('A'))!).delete();
      await manager.dispose();
      final unrelated = File('${root.path}/unrelated');
      await unrelated.writeAsString('keep');
      manager = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
      );
      await limit(8);
      expect(await manager.hasValidCache('A'), isFalse);
      expect(await manager.getCachedFileBytes('B'), [66, 66, 66, 66]);
      expect(await unrelated.readAsString(), 'keep');
    },
  );
  test(
    'a schema-valid corrupt checkpoint rebuilds complete payloads rather than dropping them',
    () async {
      await save('A', 4);
      await manager.dispose();
      await File('${root.path}/cacheimage-index/checkpoint.json').writeAsString(
        jsonEncode({
          'version': 1,
          'revision': 0,
          'entries': [
            {'key': 'A', 'file': '../outside', 'size': 4, 'use': 1},
          ],
        }),
      );
      manager = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
      );
      expect(await manager.getCachedFileBytes('A'), [65, 65, 65, 65]);
    },
  );

  test(
    'rebuilds corrupt metadata from owned complete generations and removes orphan partials',
    () async {
      await limit(8);
      await save('A', 4);
      await save('B', 4);
      await manager.dispose();
      await File(
        '${root.path}/cacheimage-index/checkpoint.json',
      ).writeAsString('{broken');
      await File(
        '${root.path}/cacheimage-transfers/orphan.partial',
      ).writeAsBytes([1]);
      manager = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
      );
      await limit(8);
      expect(await manager.getCachedFileBytes('A'), [65, 65, 65, 65]);
      expect(await manager.getCachedFileBytes('B'), [66, 66, 66, 66]);
      expect(
        await File('${root.path}/cacheimage-transfers/orphan.partial').exists(),
        isFalse,
      );
    },
  );

  test(
    'a truncated journal preserves the completed use prefix after restart',
    () async {
      await limit(8);
      await save('A', 4);
      await save('B', 4);
      // Checkpoint establishes the initial entries; following real use is journaled.
      await manager.dispose();
      manager = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
      );
      await limit(8);
      await manager.getCachedFileBytes('A');
      await File(
        '${root.path}/cacheimage-index/journal.jsonl',
      ).writeAsString('{truncated', mode: FileMode.append);
      final recovered = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
      );
      await recovered.setMaxBytes(8);
      await recovered.saveFile('C', Uint8List.fromList([67, 67, 67, 67]));
      expect(await recovered.hasValidCache('B'), isFalse);
      expect(await recovered.hasValidCache('A'), isTrue);
      await recovered.dispose();
    },
  );

  test(
    'bookkeeping write failure does not break an already readable image',
    () async {
      await save('A', 4);
      final journal = File('${root.path}/cacheimage-index/journal.jsonl');
      await journal.delete();
      await Directory(journal.path).create();
      expect(await manager.getCachedFileBytes('A'), [65, 65, 65, 65]);
      await Directory(journal.path).delete();
    },
  );
}
