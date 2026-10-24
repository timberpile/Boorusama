import 'package:boorusama/boorus/danbooru/danbooru.dart';
import 'package:boorusama/boorus/philomena/philomena.dart';
import 'package:boorusama/boorus/philomena/tags/color.dart';
import 'package:boorusama/core/bookmarks/src/providers/suggestion_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_tag_index.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/tags/tag/colors.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/themes/configs/providers.dart';
import 'package:boorusama/core/themes/configs/types.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final custom in [false, true]) {
      for (final dynamic in [false, true]) {
        test(
          'bookmark origin palettes: $brightness/$custom/$dynamic',
          () async {
            const view = BookmarkView.all();
            const danbooru = BookmarkTagSource(
              url: 'https://danbooru.donmai.us/',
              booruType: BooruType.danbooru,
            );
            const philomena = BookmarkTagSource(
              url: 'https://derpibooru.org/',
              booruType: BooruType.philomena,
            );
            final settings = custom
                ? ColorSettings.fromPredefinedScheme('coral_pink')
                : null;
            final scheme = ColorScheme.fromSeed(
              seedColor: Colors.purple,
              brightness: brightness,
            );
            final container = ProviderContainer(
              overrides: [
                booruEngineRegistryProvider.overrideWith((ref) {
                  final registry = BooruRegistry()
                    ..register(BooruType.danbooru, createDanbooru())
                    ..register(BooruType.philomena, createPhilomena());
                  return BooruEngineRegistry()
                    ..register(
                      BooruType.danbooru,
                      registry.createEngine(
                        registry.parseFromConfig('danbooru'),
                        ref,
                      ),
                    )
                    ..register(
                      BooruType.philomena,
                      registry.createEngine(
                        registry.parseFromConfig('philomena'),
                        ref,
                      ),
                    );
                }),
                customColorsProvider.overrideWithValue(settings),
                colorSchemeProvider.overrideWithValue(scheme),
                enableDynamicColoringProvider.overrideWithValue(dynamic),
                bookmarkTagIndexProvider.overrideWith(
                  (ref, _) async => BookmarkTagIndex([
                    BookmarkTagEntry(
                      tag: 'pony',
                      count: 1,
                      sources: {
                        philomena: const {'general'},
                      },
                    ),
                    BookmarkTagEntry(
                      tag: 'conflict',
                      count: 2,
                      sources: {
                        danbooru: const {'artist'},
                        philomena: const {'character'},
                      },
                    ),
                  ]),
                ),
              ],
            );
            addTearDown(container.dispose);
            final indexSubscription = container.listen(
              bookmarkTagIndexProvider(view),
              (_, _) {},
            );
            addTearDown(indexSubscription.close);
            await container.read(bookmarkTagIndexProvider(view).future);
            final palette = custom
                ? getTagColorsFromColorSettings(settings)!
                : const PhilomenaTagColorGenerator().generateColors(
                    TagColorsOptions(brightness: brightness),
                  );
            final expected = dynamic
                ? palette.general.harmonizeWith(scheme.primary)
                : palette.general;
            expect(
              await container.read(
                bookmarkTagColorProvider((view, 'pony', brightness)).future,
              ),
              expected,
            );
            expect(
              await container.read(
                bookmarkTagColorProvider((view, 'conflict', brightness)).future,
              ),
              isNull,
            );
            expect(
              await container.read(
                bookmarkTagColorProvider((view, 'missing', brightness)).future,
              ),
              isNull,
            );
          },
        );
      }
    }
  }
}
