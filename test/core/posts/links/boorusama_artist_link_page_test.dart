import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/links/boorusama_artist_link_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

String uri(String host, {String name = 'artist'}) => Uri(
  scheme: 'boorusama', host: 'artist', path: '/open',
  queryParameters: {'v': '1', 'engine': 'danbooru', 'site': 'https://$host/', 'name': name},
).toString();

BooruConfig profile(String suffix, String host) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': '00000000-0000-4000-8000-00000000000$suffix',
  'name': 'Profile $suffix', 'url': 'https://$host/',
  'booruId': BooruType.danbooru.id, 'booruIdHint': BooruType.danbooru.id,
});

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  testWidgets('selects the linked account scope without changing Browse', (tester) async {
    final unrelated = profile('1', 'unrelated.test');
    final first = profile('2', 'artist.test');
    final second = profile('3', 'artist.test');
    final address = ValueNotifier(uri('artist.test'));
    addTearDown(address.dispose);
    final container = ProviderContainer(overrides: [
      booruConfigProvider.overrideWith(() => BooruConfigNotifier(initialConfigs: [unrelated, first, second])),
      initialSettingsBooruConfigProvider.overrideWithValue(unrelated),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: BooruLocalization(child: MaterialApp(
        builder: (context, child) => KurumiTheme(data: KurumiThemeData.fromMaterial(Theme.of(context)), child: child!),
        home: ValueListenableBuilder(
          valueListenable: address,
          builder: (context, value, _) => BoorusamaArtistLinkPage(
            uri: value,
            artistBuilder: (_, name, profile) => Consumer(
              builder: (_, ref, _) => Text('$name:${ref.watch(currentReadOnlyBooruConfigProvider).id}'),
            ),
          ),
        ),
      )),
    ));
    expect(find.text('Profile 1'), findsNothing);
    expect(find.text('Profile 2'), findsOneWidget);
    expect(find.text('Profile 3'), findsOneWidget);
    await tester.tap(find.text('Profile 3'));
    await tester.pumpAndSettle();
    expect(find.text('artist:${second.id}'), findsOneWidget);
    expect(container.read(currentBooruConfigProvider), unrelated);
    address.value = uri('missing.test');
    await tester.pumpAndSettle();
    expect(find.text('artist:${second.id}'), findsNothing);
    expect(find.text('https://missing.test'), findsOneWidget);
    expect(container.read(currentBooruConfigProvider), unrelated);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing profile never opens the unrelated sole account', (tester) async {
    var opened = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [booruConfigProvider.overrideWith(() => BooruConfigNotifier(initialConfigs: [profile('1', 'other.test')]))],
      child: BooruLocalization(child: MaterialApp(
        builder: (context, child) => KurumiTheme(data: KurumiThemeData.fromMaterial(Theme.of(context)), child: child!),
        home: BoorusamaArtistLinkPage(
          uri: uri('missing.test'),
          artistBuilder: (_, _, _) { opened = true; return const SizedBox(); },
        ),
      )),
    ));
    expect(opened, isFalse);
    expect(find.text('https://missing.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
