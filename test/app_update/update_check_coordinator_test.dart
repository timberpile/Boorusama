import 'dart:async';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/foundation/app_update/src/types/update_status.dart';
import 'package:boorusama/foundation/app_update/src/update_check_coordinator.dart';

void main() {
  test(
    'reuses a successful check within 24 hours across coordinators',
    () async {
      final cache = <String, String>{};
      var checks = 0;
      var now = DateTime.utc(2026, 10, 15);

      UpdateCheckCoordinator makeCoordinator() => UpdateCheckCoordinator(
        checkForUpdate: () async {
          checks++;
          return const UpdateNotAvailable();
        },
        load: () => cache['update'],
        save: (value) async {
          cache['update'] = value;
        },
        clock: () => now,
      );

      expect(await makeCoordinator().check(), isA<UpdateNotAvailable>());
      now = now.add(const Duration(hours: 23));
      final nextProcess = makeCoordinator();
      expect(nextProcess.isCheckDue, isFalse);
      expect(await nextProcess.check(), isA<UpdateNotAvailable>());
      expect(checks, 1);

      now = now.add(const Duration(hours: 1));
      expect(nextProcess.isCheckDue, isTrue);
      await nextProcess.check();
      expect(checks, 2);
    },
  );

  test(
    'manual check bypasses cooldown and updates cached release details',
    () async {
      final cache = <String, String>{};
      var checks = 0;
      final coordinator = UpdateCheckCoordinator(
        checkForUpdate: () async {
          checks++;
          return const UpdateAvailable(
            storeVersion: '4.5.0-timberpile.5',
            currentVersion: '4.5.0-timberpile.4',
            releaseNotes: 'Changes',
            storeUrl:
                'https://github.com/timberpile/Boorusama/releases/tag/v4.5.0-timberpile.5',
            githubBuildNumber: 189,
          );
        },
        load: () => cache['update'],
        save: (value) async {
          cache['update'] = value;
        },
        clock: () => DateTime.utc(2026, 10, 15),
      );

      await coordinator.check();
      await coordinator.check();
      expect(checks, 1);
      await coordinator.check(force: true);
      expect(checks, 2);
      expect(coordinator.cachedStatus, isA<UpdateAvailable>());
      final status = coordinator.cachedStatus! as UpdateAvailable;
      expect(status.githubBuildNumber, 189);
    },
  );

  test('failed checks are not cached and back off for an hour', () async {
    var now = DateTime.utc(2026, 10, 15);
    var checks = 0;
    final coordinator = UpdateCheckCoordinator(
      checkForUpdate: () async {
        checks++;
        return const UpdateError('Offline');
      },
      load: () => null,
      save: (_) async {},
      clock: () => now,
    );

    expect(await coordinator.check(), isA<UpdateError>());
    expect(coordinator.isCheckDue, isFalse);
    await coordinator.check();
    expect(checks, 1);
    now = now.add(const Duration(hours: 1));
    expect(coordinator.isCheckDue, isTrue);
    await coordinator.check();
    expect(checks, 2);
  });
  test(
    'preserves errors during backoff and recovers after a manual retry',
    () async {
      String? cache;
      var fail = false;
      var checks = 0;
      final coordinator = UpdateCheckCoordinator(
        checkForUpdate: () async {
          checks++;
          return fail
              ? const UpdateError('Offline')
              : const UpdateNotAvailable();
        },
        load: () => cache,
        save: (value) async {
          cache = value;
        },
      );
      await coordinator.check();
      fail = true;
      expect(await coordinator.check(force: true), isA<UpdateError>());
      expect(await coordinator.check(), isA<UpdateError>());
      expect(coordinator.cachedStatus, isA<UpdateError>());
      expect(checks, 2);
      fail = false;
      expect(await coordinator.check(force: true), isA<UpdateNotAvailable>());
      expect(coordinator.cachedStatus, isA<UpdateNotAvailable>());
    },
  );

  test('rate limits successful checks even when cache writes fail', () async {
    var now = DateTime.utc(2026, 10, 15);
    var checks = 0;
    final coordinator = UpdateCheckCoordinator(
      checkForUpdate: () async {
        checks++;
        return const UpdateNotAvailable();
      },
      load: () => null,
      save: (_) async => throw StateError('Disk full'),
      clock: () => now,
    );
    await coordinator.check();
    expect(coordinator.lastCheckedAt, now);
    expect(coordinator.isCheckDue, isFalse);
    await coordinator.check();
    expect(checks, 1);
    now = now.add(const Duration(hours: 24));
    await coordinator.check();
    expect(checks, 2);
  });

  test('concurrent automatic and manual checks share one request', () async {
    final response = Completer<UpdateStatus>();
    var checks = 0;
    final coordinator = UpdateCheckCoordinator(
      checkForUpdate: () {
        checks++;
        return response.future;
      },
      load: () => null,
      save: (_) async {},
    );
    final automatic = coordinator.check();
    final manual = coordinator.check(force: true);
    expect(checks, 1);
    response.complete(const UpdateNotAvailable());
    expect(await automatic, same(await manual));
  });
}
