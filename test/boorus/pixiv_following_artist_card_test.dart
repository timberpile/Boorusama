import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/following/artist_card.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() async => ensureI18nInitialized('en-US'));

  testWidgets('actual card covers explicit previews and resets a revealed slot', (
    tester,
  ) async {
    final work = ValueNotifier(1);
    addTearDown(work.dispose);
    var opens = 0;
    await _pump(tester, work: work, cover: true, onOpen: () => opens++);
    expect(find.text('EXPLICIT'), findsOneWidget);

    await tester.tap(find.text('EXPLICIT'));
    await tester.pump();
    expect(find.text('EXPLICIT'), findsNothing);
    expect(opens, 0);

    work.value = 2;
    await tester.pump();
    expect(find.text('EXPLICIT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actual card respects disabled cover and retains artist action', (
    tester,
  ) async {
    final work = ValueNotifier(1);
    addTearDown(work.dispose);
    var opens = 0;
    await _pump(tester, work: work, cover: false, onOpen: () => opens++);
    expect(find.text('EXPLICIT'), findsNothing);
    await tester.tap(find.text('Test artist'));
    await tester.pump();
    expect(opens, 1);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, {
  required ValueNotifier<int> work,
  required bool cover,
  required VoidCallback onOpen,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      // Exercise the actual card/cover without fetching artwork or credentials.
      automaticMediaLoadingEnabledProvider.overrideWithValue(false),
      imageListingSettingsProvider.overrideWithValue(
        ImageListingSettings.fromJson({
          'imageBorderRadius': 8.0,
          'mediaBlurCondition': cover ? 'explicitOnly' : 'none',
        }),
      ),
    ],
    child: BooruLocalization(
      child: MaterialApp(
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 320,
              child: ValueListenableBuilder<int>(
                valueListenable: work,
                builder: (context, id, _) => PixivFollowingArtistCard(
                  config: BooruConfig.empty.auth,
                  maxRestriction: 1,
                  onOpen: onOpen,
                  artist: PixivFollowingArtist(
                    user: const PixivIllustUser(id: 7, name: 'Test artist'),
                    illusts: [PixivIllustDto.fromJson({
                      'id': id, 'user': {'id': 7}, 'x_restrict': 1,
                      'visible': true,
                      'image_urls': {
                        'square_medium': 'https://i.pximg.net/$id.jpg',
                      },
                    })],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
