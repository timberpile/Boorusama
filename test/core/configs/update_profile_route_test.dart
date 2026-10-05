import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/defaults/widgets.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/create/routes.dart';
import 'package:boorusama/core/configs/create/create.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  final profile = BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: BooruType.danbooru,
      url: 'https://danbooru.donmai.us',
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': '00000000-0000-4000-8000-000000000002',
  });
  final otherProfile = BooruConfig.fromJson({
    ...profile.toJson(),
    'id': '00000000-0000-4000-8000-000000000003',
    'name': 'Other profile',
  });
  for (final tab in [null, 'search']) {
    testWidgets('opens the UUID profile editor with initial tab $tab', (
      tester,
    ) async {
      EditBooruConfigId? opened;
      String? openedTab;
      final builder = _EditorBuilder((id, tab) {
        opened = id;
        openedTab = tab;
      });
      final container = ProviderContainer(
        overrides: [
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: [otherProfile, profile]),
          ),
          booruBuilderProvider.overrideWith((ref, config) => builder),
        ],
      );
      final router = container.read(
        Provider(
          (ref) => GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const SizedBox(),
                routes: [updateBooruConfigRoutes(ref)],
              ),
            ],
            initialLocation: Uri(
              path: '/boorus/${profile.id}/update',
              queryParameters: {'q': ?tab},
            ).toString(),
          ),
        ),
      );
      addTearDown(router.dispose);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('profile editor'), findsOneWidget);
      expect(opened, EditBooruConfigId.fromConfig(profile));
      expect(openedTab, tab);
      expect(tester.takeException(), isNull);
    });
  }
  for (final id in ['00000000-0000-4000-8000-000000000001', 'invalid', '123']) {
    testWidgets('shows the fallback for unknown profile reference $id', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: [otherProfile, profile]),
          ),
        ],
      );
      final router = container.read(
        Provider(
          (ref) => GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const SizedBox(),
                routes: [updateBooruConfigRoutes(ref)],
              ),
            ],
            initialLocation: '/boorus/$id/update',
          ),
        ),
      );
      addTearDown(router.dispose);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Booru not found or not loaded yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _EditorBuilder extends BaseBooruBuilder {
  _EditorBuilder(this.onOpen);
  final void Function(EditBooruConfigId, String?) onOpen;

  @override
  UpdateConfigPageBuilder get updateConfigPageBuilder =>
      (context, id, {backgroundColor, initialTab}) {
        onOpen(id, initialTab);
        return const Scaffold(body: Text('profile editor'));
      };
}
