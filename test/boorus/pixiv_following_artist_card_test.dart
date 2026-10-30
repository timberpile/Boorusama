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
  setUpAll(() => ensureI18nInitialized('en-US'));

  testWidgets(
    'actual card covers explicit previews and resets a revealed slot',
    (
      tester,
    ) async {
      final work = ValueNotifier(const _Preview());
      addTearDown(work.dispose);
      var opens = 0;
      await _pump(tester, work: work, cover: true, onOpen: () => opens++);
      expect(find.text('EXPLICIT'), findsOneWidget);

      await tester.tap(find.text('EXPLICIT'));
      await tester.pump();
      expect(find.text('EXPLICIT'), findsNothing);
      expect(opens, 0);

      work.value = const _Preview(workId: 2);
      await tester.pump();
      expect(find.text('EXPLICIT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final replacement in [
    const _Preview(url: 'https://i.pximg.net/replacement.jpg'),
    const _Preview(artistId: 8),
    _Preview(
      config: BooruConfig.empty.copyWith(apiKey: 'replacement-fixture').auth,
    ),
  ]) {
    testWidgets('revealed preview resets for replacement $replacement', (
      tester,
    ) async {
      final work = ValueNotifier(const _Preview());
      addTearDown(work.dispose);
      await _pump(tester, work: work, cover: true, onOpen: () {});
      await tester.tap(find.text('EXPLICIT'));
      await tester.pump();
      expect(find.text('EXPLICIT'), findsNothing);
      work.value = replacement;
      await tester.pump();
      expect(find.text('EXPLICIT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('actual card respects disabled cover and retains artist action', (
    tester,
  ) async {
    final work = ValueNotifier(const _Preview());
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

Future<void> _pump(
  WidgetTester tester, {
  required ValueNotifier<_Preview> work,
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
              child: ValueListenableBuilder<_Preview>(
                valueListenable: work,
                builder: (context, preview, _) => PixivFollowingArtistCard(
                  config: preview.config ?? BooruConfig.empty.auth,
                  maxRestriction: 1,
                  onOpen: onOpen,
                  artist: PixivFollowingArtist(
                    user: PixivIllustUser(
                      id: preview.artistId,
                      name: 'Test artist',
                    ),
                    illusts: [
                      PixivIllustDto.fromJson({
                        'id': preview.workId,
                        'user': {'id': preview.artistId},
                        'x_restrict': 1,
                        'visible': true,
                        'image_urls': {
                          'square_medium': preview.url,
                        },
                      }),
                    ],
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

class _Preview {
  const _Preview({
    this.workId = 1,
    this.artistId = 7,
    this.url = 'https://i.pximg.net/1.jpg',
    this.config,
  });
  final int workId;
  final int artistId;
  final String url;
  final BooruConfigAuth? config;
  @override
  String toString() => 'artist=$artistId url=$url profile=${config?.hashCode}';
}
