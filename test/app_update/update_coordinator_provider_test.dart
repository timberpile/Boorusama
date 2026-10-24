import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/foundation/app_update/src/providers.dart';
import 'package:boorusama/foundation/app_update/src/types/app_update_checker.dart';
import 'package:boorusama/foundation/app_update/src/types/update_status.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _Store implements MiscDataStore {
  final values = <String, String>{};

  @override
  String? get(String key) => values[key];

  @override
  Future<void> put(String key, String value) async => values[key] = value;
}

class _Checker implements AppUpdateChecker {
  var calls = 0;

  @override
  Future<UpdateStatus> checkForUpdate() async {
    calls++;
    return const UpdateNotAvailable();
  }
}

void main() {
  test(
    'coordinator persists cooldown through the injected runtime store',
    () async {
      final store = _Store();
      final checker = _Checker();
      ProviderContainer createContainer(String build) => ProviderContainer(
        overrides: [
          miscDataStoreProvider.overrideWithValue(store),
          appUpdateCheckerProvider.overrideWithValue(checker),
          packageInfoProvider.overrideWithValue(
            PackageInfo(
              appName: 'Boorusama',
              packageName: 'com.timberpile.boorusama',
              version: '4.6.1',
              buildNumber: build,
            ),
          ),
        ],
      );

      final first = createContainer('190');
      await first.read(appUpdateCoordinatorProvider).check();
      first.dispose();
      expect(checker.calls, 1);
      expect(store.values, hasLength(1));

      final restarted = createContainer('190');
      addTearDown(restarted.dispose);
      expect(restarted.read(appUpdateCoordinatorProvider).isCheckDue, isFalse);
      await restarted.read(appUpdateCoordinatorProvider).check();
      expect(checker.calls, 1);

      final upgraded = createContainer('191');
      addTearDown(upgraded.dispose);
      await upgraded.read(appUpdateCoordinatorProvider).check();
      expect(checker.calls, 2);
      expect(store.values, hasLength(2));
    },
  );
}
