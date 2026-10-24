import 'package:boorusama/core/announcements/providers.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../application/support/fake_booru_backend.dart';

class _Announcements implements AnnouncementRepository {
  final hosts = <String>[];
  @override
  Future<List<AppAnnouncement>> getAnnouncements({
    required String booruKey,
    required String host,
    required Future<Set<String>> dismissedIds,
  }) async {
    await dismissedIds;
    hosts.add(host);
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'announcements use the destination auth scope on startup and resume',
    () async {
      final backend = FakeBooruBackend();
      final repository = _Announcements();
      final root = ProviderContainer(
        overrides: [
          currentReadOnlyBooruConfigAuthProvider.overrideWithValue(
            backend.config.auth,
          ),
          announcementRepositoryProvider.overrideWithValue(repository),
          dismissedAnnouncementIdsProvider.overrideWith((ref) async => {}),
        ],
      );
      addTearDown(root.dispose);
      for (final BooruConfig profile in [backend.configB, backend.config]) {
        final child = ProviderContainer(
          parent: root,
          overrides: [
            currentReadOnlyBooruConfigAuthProvider.overrideWithValue(
              profile.auth,
            ),
          ],
        );
        addTearDown(child.dispose);
        expect(await child.read(appAnnouncementsProvider.future), isEmpty);
      }
      expect(repository.hosts, [
        'headless-b.booru.test',
        'headless.booru.test',
      ]);
    },
  );
}
