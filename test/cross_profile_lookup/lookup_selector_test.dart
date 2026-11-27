import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/lookup_preferences.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/lookup_selector.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/material.dart';

import '../support/fakes/memory_repositories.dart';

void main() {
  BooruConfig profile(int id, String name, BooruType engine, String url) =>
      BooruConfig.fromJson({
        ...BooruConfig.defaultConfig(
          booruType: engine,
          url: url,
          customDownloadFileNameFormat: null,
        ).toJson(),
        'id': '00000000-0000-4000-8000-00000000000$id',
        'name': name,
      });

  final safe = profile(
    1,
    'Default profile',
    BooruType.danbooru,
    'https://safebooru.donmai.us/',
  );
  final unsupported = profile(
    2,
    'Unsupported profile',
    BooruType.e621,
    'https://e621.net/',
  );
  final danbooru = profile(
    3,
    'Danbooru profile',
    BooruType.danbooru,
    'https://danbooru.donmai.us/',
  );

  testWidgets(
    'settings shows guest IQDB and saves it only after explicit opt-in',
    (tester) async {
      final store = MemoryMiscDataStore();
      final container = ProviderContainer(
        overrides: [
          miscDataStoreProvider.overrideWithValue(store),
          orderedProfileConfigsProvider.overrideWithValue([safe, unsupported]),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => selectLookupTargets(
                    context,
                    container,
                    available: configuredLookupMethods,
                    settings: true,
                  ),
                  child: const Text('Open selector'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open selector'));
      await tester.pumpAndSettle();
      expect(find.text('Unsupported profile'), findsNothing);
      final iqdb = find.widgetWithText(FilterChip, 'Danbooru IQDB');
      expect(iqdb, findsOneWidget);
      expect(tester.widget<FilterChip>(iqdb).selected, isFalse);
      expect(
        find.text('IQDB requires a Danbooru username and API key.'),
        findsOneWidget,
      );
      await tester.tap(iqdb);
      await tester.pumpAndSettle();

      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Enable Danbooru IQDB?'), findsOneWidget);
      expect(container.read(lookupPreferencesProvider).allowIqdb, isFalse);
      expect(container.read(lookupPreferencesProvider).profiles, isNull);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(iqdb, findsOneWidget);
      expect(container.read(lookupPreferencesProvider).allowIqdb, isFalse);
      expect(container.read(lookupPreferencesProvider).profiles, isNull);

      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Enable IQDB'));
      await tester.pumpAndSettle();
      expect(iqdb, findsNothing);

      final stored = ProviderContainer(
        overrides: [
          miscDataStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(stored.dispose);
      final preferences = stored.read(lookupPreferencesProvider);
      expect(preferences.allowIqdb, isTrue);
      expect(
        preferences.methodsFor(safe),
        contains(PostLookupMatchKind.similarImage),
      );

      await tester.tap(find.text('Open selector'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(iqdb).selected, isTrue);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Enable Danbooru IQDB?'), findsNothing);
      expect(iqdb, findsNothing);
    },
  );

  test(
    'both first-party hosts advertise IQDB independently of credentials',
    () {
      for (final guest in [safe, danbooru]) {
        expect(
          configuredLookupMethods(guest),
          contains(PostLookupMatchKind.similarImage),
        );
        expect(supportsIqdbLookup(guest), isFalse);
        final signedIn = guest.copyWith(
          login: 'fixture-user',
          apiKey: 'fixture-key',
        );
        expect(supportsIqdbLookup(signedIn), isTrue);
        expect(
          iqdbLookupEndpoint(signedIn),
          Uri.https(Uri.parse(guest.url).host, '/iqdb_queries.json'),
        );
      }
    },
  );
}
