import 'package:boorusama/core/settings/src/pages/appearance/image_listing_settings_section.dart';
import 'package:boorusama/core/settings/src/pages/appearance/posts_per_page_dialog.dart';
import 'package:boorusama/core/settings/src/types/utils.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  test('custom page counts accept only integers within 10–200', () {
    expect(getPostsPerPagePossibleValue(), [20, 40, 60, 100, 200]);
    expect(parseCustomPostsPerPage('10'), 10);
    expect(parseCustomPostsPerPage('75'), 75);
    expect(parseCustomPostsPerPage('200'), 200);

    final settings = Settings.defaultSettings.copyWith(
      listing: Settings.defaultSettings.listing.copyWith(postsPerPage: 75),
    );
    expect(Settings.fromJson(settings.toJson()).listing.postsPerPage, 75);

    for (final input in ['', 'abc', '1.5', '-1', '9', '201']) {
      expect(parseCustomPostsPerPage(input), isNull, reason: input);
    }
  });

  testWidgets(
    'custom post count is editable and preset selection replaces it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final initial = Settings.defaultSettings.listing.copyWith(
        postsPerPage: 75,
      );
      ImageListingSettings? updated;

      Widget section(ImageListingSettings listing) => BooruLocalization(
        child: ProviderScope(
          child: MaterialApp(
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ImageListingSettingsSection(
                  listing: listing,
                  onUpdate: (change) => updated = change(listing),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(section(initial));

      KurumiOptionDropDownButton<int> picker() =>
          tester.widget<KurumiOptionDropDownButton<int>>(
            find.byType(KurumiOptionDropDownButton<int>),
          );

      expect(picker().value, 0);
      expect(picker().items.map((item) => item.value), [
        20,
        40,
        60,
        100,
        200,
        0,
      ]);
      expect((picker().selectedItemBuilder!(0) as Text).data, '75');

      picker().onChanged(0);
      await tester.pumpAndSettle();
      expect(find.byType(PostsPerPageDialog), findsOneWidget);

      final field = find.byType(KurumiTextField);
      await tester.enterText(field, '201');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a whole number between 10 and 200.'),
        findsOneWidget,
      );
      expect(updated, isNull);

      await tester.enterText(field, '90');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(PostsPerPageDialog), findsNothing);
      expect(updated?.postsPerPage, 90);

      await tester.pumpWidget(section(updated!));
      expect(picker().value, 0);
      expect((picker().selectedItemBuilder!(0) as Text).data, '90');

      picker().onChanged(100);
      expect(updated?.postsPerPage, 100);

      await tester.pumpWidget(section(updated!));
      expect(picker().value, 100);
      expect(picker().items.map((item) => item.value), [
        20,
        40,
        60,
        100,
        200,
        0,
      ]);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'custom dialog stays usable at 320px with text scale $scale and keyboard',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() {
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
          return tester.binding.setSurfaceSize(null);
        });
        int? result;

        await tester.pumpWidget(
          BooruLocalization(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: child!,
                ),
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showPostsPerPageDialog(
                        context,
                        currentValue: 75,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final field = find.byType(KurumiTextField);
        final submit = find.widgetWithText(FilledButton, 'OK');
        await tester.enterText(field, '201');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(
          find.text('Enter a whole number between 10 and 200.'),
          findsOneWidget,
        );
        expect(result, isNull);
        await tester.ensureVisible(submit);
        expect(tester.getBottomRight(submit).dy, lessThanOrEqualTo(340));
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(field);
        await tester.enterText(field, '90');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(result, 90);
        expect(find.byType(PostsPerPageDialog), findsNothing);

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final cancel = find.widgetWithText(TextButton, 'Cancel');
        await tester.ensureVisible(cancel);
        expect(tester.getBottomRight(cancel).dy, lessThanOrEqualTo(340));
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(find.byType(PostsPerPageDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
