import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/settings/src/pages/appearance/image_listing_settings_section.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:foundation/foundation.dart';
import 'package:boorusama/core/images/image_quality.dart';
import 'package:boorusama/core/settings/src/pages/appearance/image_viewer_settings_section.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));
  testWidgets(
    'post quality updates latest viewer state independently of thumbnail quality',
    (tester) async {
      var latest = Settings.defaultSettings.viewer;
      ImageViewerSettings Function(ImageViewerSettings)? change;
      await tester.pumpWidget(
        BooruLocalization(
          child: ProviderScope(
            child: MaterialApp(
              builder: (context, child) => KurumiTheme(
                data: KurumiThemeData.fromMaterial(
                  Theme.of(context).copyWith(platform: TargetPlatform.iOS),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: PostQualitySetting(
                    value: latest.postQuality,
                    onUpdate: (value) => change = value,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Post quality'), findsOneWidget);
      final selector = tester.widget<KurumiOptionDropDownButton<PostQuality>>(
        find.byType(KurumiOptionDropDownButton<PostQuality>),
      );
      expect(selector.value, PostQuality.high);
      expect(selector.items.length, 2);
      expect(find.text('Highest'), findsNothing);
      expect(find.text('High'), findsOneWidget);
      selector.onChanged(PostQuality.medium);
      latest = latest.copyWith(loadOriginalOnZoom: false);
      final updated = change!(latest);
      expect(updated.postQuality, PostQuality.medium);
      expect(updated.loadOriginalOnZoom, isFalse);
      expect(
        Settings.defaultSettings.listing.imageQuality,
        ImageQuality.automatic,
      );
    },
  );
  testWidgets(
    'serialized Original migrates to High with only supported preset options',
    (tester) async {
      await tester.pumpWidget(
        BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
            home: Scaffold(
              body: PostQualitySetting(
                value: ImageViewerSettings.fromJson(const {
                  'postQuality': 3,
                }).postQuality,
                onUpdate: (_) {},
              ),
            ),
          ),
        ),
      );
      final selector = tester.widget<KurumiOptionDropDownButton<PostQuality>>(
        find.byType(KurumiOptionDropDownButton<PostQuality>),
      );
      expect(selector.value, PostQuality.high);
      expect(selector.items.map((item) => item.value), PostQuality.values);
      expect(find.text('Original'), findsNothing);
      expect(find.text('Highest'), findsNothing);
      expect(find.text('High'), findsOneWidget);
    },
  );
  testWidgets('German post selector shows Mittel and Hoch', (tester) async {
    await tester.runAsync(() => ensureI18nInitialized('de-DE'));
    addTearDown(() => ensureI18nInitialized('en-US'));
    await tester.pumpWidget(
      BooruLocalization(
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
            home: Scaffold(
              body: PostQualitySetting(
                value: PostQuality.high,
                onUpdate: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    final finder = find.byType(KurumiOptionDropDownButton<PostQuality>);
    final selector = tester.widget<KurumiOptionDropDownButton<PostQuality>>(
      finder,
    );
    expect(
      Localizations.localeOf(tester.element(finder)),
      const Locale('de', 'DE'),
    );
    expect(selector.value, PostQuality.high);
    expect(selector.items.map((item) => (item.child as Text).data), [
      'Mittel',
      'Hoch',
    ]);
    expect(selector.items.map((item) => item.value), PostQuality.values);
    expect(selector.items.map((item) => item.value?.toData()), [2, 4]);
  });
  for (final locale in [
    (language: 'en-US', labels: ['Auto', 'Low', 'Medium', 'High']),
    (language: 'de-DE', labels: ['Automatisch', 'Niedrig', 'Mittel', 'Hoch']),
  ]) {
    for (final surface in ['appearance', 'quick grid']) {
      testWidgets(
        '${locale.language} $surface thumbnail labels retain independent stored values',
        (
          tester,
        ) async {
          await tester.runAsync(() => ensureI18nInitialized(locale.language));
          addTearDown(() => ensureI18nInitialized('en-US'));
          final listing = Settings.defaultSettings.listing.copyWith(
            imageQuality: ImageQuality.high,
          );
          final controller = PostGridController<Post>(
            fetcher: (_) => TaskEither.right(PostResult.empty()),
            blacklistedTagsFetcher: () async => const {},
            mountedChecker: () => true,
            duplicateTracker: PostDuplicateTracker(),
            onError: (_) {},
          );
          addTearDown(controller.dispose);
          final config = BooruConfig.defaultConfig(
            booruType: BooruType.danbooru,
            url: 'https://quality.test',
            customDownloadFileNameFormat: null,
          );
          await tester.pumpWidget(
            BooruLocalization(
              child: ProviderScope(
                overrides: [
                  imageListingSettingsProvider.overrideWithValue(listing),
                  hasCustomListingSettingsProvider.overrideWithValue(false),
                  currentReadOnlyBooruConfigProvider.overrideWithValue(config),
                ],
                child: Builder(
                  builder: (context) => MaterialApp(
                    locale: context.locale,
                    localizationsDelegates: context.localizationDelegates,
                    supportedLocales: context.supportedLocales,
                    builder: (context, child) => KurumiTheme(
                      data: KurumiThemeData.fromMaterial(Theme.of(context)),
                      child: child!,
                    ),
                    home: Scaffold(
                      body: SingleChildScrollView(
                        child: surface == 'appearance'
                            ? ImageListingSettingsSection(
                                listing: listing,
                                onUpdate: (_) {},
                              )
                            : PostGridActionSheet(
                                postController: controller,
                                onModeChanged: (_) {},
                                onGridChanged: (_) {},
                                onImageListChanged: (_) {},
                                onImageQualityChanged: (_) {},
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final selector = tester
              .widget<KurumiOptionDropDownButton<ImageQuality>>(
                find.byType(KurumiOptionDropDownButton<ImageQuality>),
              );
          expect(selector.value, ImageQuality.high);
          expect(
            Localizations.localeOf(
              tester.element(
                find.byType(KurumiOptionDropDownButton<ImageQuality>),
              ),
            ),
            Locale(
              locale.language.split('-').first,
              locale.language.split('-').last,
            ),
          );
          expect(
            selector.items.map((item) => (item.child as Text).data),
            locale.labels,
          );
          expect(
            selector.items.map((item) => item.value),
            ImageQuality.nonOriginalValues,
          );
          expect(selector.items.map((item) => item.value?.toData()), [
            0,
            1,
            2,
            4,
          ]);
        },
      );
    }
  }
}
