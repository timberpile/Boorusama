import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/home/widgets.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_profile_scope.dart';
import 'package:boorusama/core/navigation/navigation_catalog.dart';
import 'package:boorusama/core/navigation/navigation_catalog_provider.dart';
import 'package:boorusama/core/navigation/profile_context_menu.dart';
import 'package:boorusama/core/navigation/navigation_profile_picker.dart';
import 'package:boorusama/foundation/app_update/src/providers.dart';
import 'package:boorusama/foundation/app_update/src/types/update_status.dart';
import 'package:boorusama/foundation/app_update/src/widgets/app_update_button.dart';
import 'package:boorusama/foundation/app_update/src/widgets/app_update_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import 'core/posts/details/progressive_image_test_utils.dart' as images;

const _available = UpdateAvailable(
  storeVersion: '2.0.0',
  currentVersion: '1.0.0',
  releaseNotes: 'Update notes',
  storeUrl: 'https://example.com/releases',
);

void main() {
  Future<void> pumpBar(
    WidgetTester tester,
    ProviderContainer container, {
    double scale = 1,
  }) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: BooruLocalization(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: const Scaffold(body: HomeSearchBar()),
        ),
      ),
    ),
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('mobile update control follows status at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final status = StateProvider<UpdateStatus>(
        (ref) => const UpdateNotAvailable(),
      );
      final container = ProviderContainer(
        overrides: [
          appUpdateStatusProvider.overrideWith(
            (ref) async => ref.watch(status),
          ),
        ],
      );
      addTearDown(container.dispose);
      await pumpBar(tester, container, scale: scale);
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateButton), findsOneWidget);
      expect(find.byType(RawAppUpdateButton), findsNothing);
      expect(find.byType(NavigationProfilePicker), findsOneWidget);

      container.read(status.notifier).state = _available;
      await tester.pumpAndSettle();
      expect(find.byType(RawAppUpdateButton).hitTestable(), findsOneWidget);
      expect(
        tester
            .widget<RawAppUpdateButton>(find.byType(RawAppUpdateButton))
            .status,
        same(_available),
      );
      expect(
        tester.getRect(find.byType(RawAppUpdateButton)).right,
        lessThanOrEqualTo(320),
      );

      for (final hidden in <UpdateStatus>[
        const UpdateNotAvailable(),
        UpdateError(StateError('offline')),
      ]) {
        container.read(status.notifier).state = hidden;
        await tester.pumpAndSettle();
        expect(find.byType(RawAppUpdateButton), findsNothing);
        expect(find.byType(NavigationProfilePicker), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unsupported update checking leaves mobile indicator hidden', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [updateChecksSupportedProvider.overrideWithValue(false)],
    );
    addTearDown(container.dispose);
    await pumpBar(tester, container);
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateButton), findsOneWidget);
    expect(find.byType(RawAppUpdateButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending update status does not show an available indicator', (
    tester,
  ) async {
    final status = Completer<UpdateStatus>();
    final container = ProviderContainer(
      overrides: [appUpdateStatusProvider.overrideWith((ref) => status.future)],
    );
    addTearDown(container.dispose);
    await pumpBar(tester, container);
    await tester.pump();
    expect(find.byType(AppUpdateButton), findsOneWidget);
    expect(find.byType(RawAppUpdateButton), findsNothing);
    status.complete(_available);
    await tester.pumpAndSettle();
    expect(find.byType(RawAppUpdateButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'update and profile controls fit together and open the existing dialog',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final profile = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': '00000000-0000-4000-8000-000000000001',
        'name': 'Profile',
        'url': 'https://example.com',
      });
      final container = ProviderContainer(
        overrides: [
          appUpdateStatusProvider.overrideWith((ref) async => _available),
          githubAndroidInstallationSupportedProvider.overrideWithValue(false),
          navigationProfilesProvider.overrideWithValue([profile]),
          navigationCatalogProvider.overrideWithValue(
            NavigationCatalog(
              profileSections: [],
              globalEntries: [],
              eligibleFavoritesProfileIds: [],
            ),
          ),
          automaticMediaLoadingEnabledProvider.overrideWithValue(false),
          faviconDioProvider.overrideWithValue(Dio()),
          defaultImageCacheManagerProvider.overrideWithValue(
            images.TestImageCache({}),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: BooruLocalization(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: DestinationScope(
                  id: DestinationId.browse(profile.id),
                  child: const HomeSearchBar(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final update = find.byType(RawAppUpdateButton);
      final picker = find.byType(ProfileContextMenuButton);
      expect(update.hitTestable(), findsOneWidget);
      expect(picker.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(update).right,
        lessThanOrEqualTo(tester.getRect(picker).left),
      );
      expect(tester.getRect(picker).right, lessThanOrEqualTo(320));
      await tester.tap(update);
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateDialog), findsOneWidget);
      expect(
        tester.widget<AppUpdateDialog>(find.byType(AppUpdateDialog)).status,
        same(_available),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
