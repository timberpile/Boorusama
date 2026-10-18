// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/downloads/sidecar/providers.dart';
import 'package:boorusama/core/downloads/sidecar/types.dart';
import 'package:boorusama/foundation/filesystem.dart';

import '../../support/fakes/memory_app_file_system.dart';

void main() {
  const media = '/memory/downloads/image.jpg';
  final snapshot = SidecarSnapshot(
    format: SidecarFormat.tags,
    tags: const ['tag'],
    quality: 'original',
  );

  late MemoryAppFileSystem fs;
  late ProviderContainer container;

  setUp(() {
    fs = MemoryAppFileSystem();
    container = ProviderContainer(
      overrides: [appFileSystemProvider.overrideWithValue(fs)],
    );
  });
  tearDown(() => container.dispose());

  test('production store completes without a failure observer', () async {
    final store = await container.read(sidecarStoreProvider.future);
    await store.prepare('completed', media, snapshot);
    await fs.writeString(media, 'saved media');

    await store.complete('completed', media);

    expect(await fs.readString('$media.txt'), 'tag\n');
    expect(await store.failures(), isEmpty);
    expect(await container.read(sidecarFailuresProvider.future), isEmpty);
  });

  test('production callbacks refresh failures and successful retry', () async {
    final subscription = container.listen(sidecarFailuresProvider, (_, _) {});
    addTearDown(subscription.close);
    expect(await container.read(sidecarFailuresProvider.future), isEmpty);
    final store = await container.read(sidecarStoreProvider.future);
    await store.prepare('retry', media, snapshot);
    await fs.writeString(media, 'saved media');
    await fs.writeString('$media.txt', 'conflicting metadata');

    await expectLater(store.complete('retry', media), throwsStateError);

    final failures = await container.read(sidecarFailuresProvider.future);
    expect(failures.single.id, 'retry');
    expect(failures.single.error, contains('Existing metadata file conflicts'));
    expect(await fs.readString(media), 'saved media');
    await fs.deleteFile('$media.txt');

    await store.retry('retry');

    expect(await container.read(sidecarFailuresProvider.future), isEmpty);
    expect(await store.failures(), isEmpty);
    expect(await fs.readString(media), 'saved media');
    expect(await fs.readString('$media.txt'), 'tag\n');
    expect(await container.read(sidecarStoreProvider.future), same(store));
  });
}
