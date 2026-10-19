import 'dart:async';

import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_profile_scope.dart';
import 'package:boorusama/core/navigation/destination_router.dart';
import 'package:boorusama/core/navigation/navigation_route_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:i18n/i18n.dart';

class _Profiles extends BooruConfigNotifier {
  _Profiles(List<BooruConfig> initial) : super(initialConfigs: initial);
  void replace(BooruConfig profile) => state = [profile];
}

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));
  testWidgets(
    'a global child cannot reuse its payload after source replacement',
    (tester) async {
      final owner = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': '00000000-0000-4000-8000-000000000002',
        'url': 'https://source.invalid/',
      });
      final profiles = _Profiles([owner]);
      const following = DestinationId.app(AppDestination.following);
      final sent = <BooruConfigAuth>[];
      final binding = DestinationRouterBinding(
        definitions: [
          DestinationRouteDefinition(
            id: following,
            builder: (_, _) => const Scaffold(body: Text('Following')),
            children: destinationChildRoutes(following, [
              GoRoute(
                path: 'action',
                builder: (_, _) => Consumer(
                  builder: (context, ref, _) => Scaffold(
                    body: TextButton(
                      onPressed: () => sent.add(ref.readConfigAuth),
                      child: const Text('Send'),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ],
        shellBuilder: (_, _, shell) => shell,
        navigatorWrapper: (_, id, _, child) =>
            DestinationScope(id: id, child: child),
      );
      final router = GoRouter.routingConfig(
        routingConfig: binding.routingConfig,
        initialLocation: following.location,
      );
      binding.attach(router);
      addTearDown(router.dispose);
      addTearDown(binding.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booruConfigProvider.overrideWith(() => profiles),
            currentReadOnlyBooruConfigProvider.overrideWithValue(
              BooruConfig.empty,
            ),
          ],
          child: BooruLocalization(
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        router.push('${following.location}/action?_profile=${owner.id}'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      expect(sent, [owner.auth]);
      profiles.replace(
        BooruConfig.fromJson({
          ...owner.toJson(),
          'url': 'https://replacement.invalid/',
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Send'), findsNothing);
      expect(sent, [owner.auth]);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Following'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
