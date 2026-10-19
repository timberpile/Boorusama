import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_profile_scope.dart';
import 'package:boorusama/core/navigation/destination_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'branch children and overlays use their live owner instead of Browse',
    (tester) async {
      final first = BooruConfig.fromJson({
        ...BooruConfig.defaultConfig(
          booruType: BooruType.danbooru,
          url: 'https://a.invalid',
          customDownloadFileNameFormat: null,
        ).toJson(),
        'id': '00000000-0000-4000-8000-000000000001',
      });
      final second = BooruConfig.fromJson({
        ...BooruConfig.defaultConfig(
          booruType: BooruType.gelbooru,
          url: 'https://b.invalid',
          customDownloadFileNameFormat: null,
        ).toJson(),
        'id': '00000000-0000-4000-8000-000000000002',
      });
      final sent = <BooruConfigAuth>[];
      final binding = DestinationRouterBinding(
        definitions: [
          DestinationRouteDefinition(
            id: DestinationId.favorites(second.id),
            builder: (_, _) => const Scaffold(body: Text('root')),
            children: [
              GoRoute(
                path: 'action',
                builder: (_, _) => Consumer(
                  builder: (context, ref, _) => Scaffold(
                    body: TextButton(
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          useRootNavigator: false,
                          builder: (_) => Consumer(
                            builder: (_, ref, _) => TextButton(
                              onPressed: () => sent.add(ref.readConfigAuth),
                              child: const Text('Send'),
                            ),
                          ),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        shellBuilder: (_, _, shell) => shell,
        navigatorWrapper: (_, id, _, child) =>
            DestinationProfileScope(profileId: id.profileId!, child: child),
      );
      final router = GoRouter.routingConfig(
        routingConfig: binding.routingConfig,
        initialLocation: DestinationId.favorites(second.id).location,
      );
      binding.attach(router);
      addTearDown(router.dispose);
      addTearDown(binding.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booruConfigProvider.overrideWith(
              () => BooruConfigNotifier(initialConfigs: [first, second]),
            ),
            currentReadOnlyBooruConfigAuthProvider.overrideWithValue(
              first.auth,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      router.push('${DestinationId.favorites(second.id).location}/action');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      expect(sent, [second.auth]);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
