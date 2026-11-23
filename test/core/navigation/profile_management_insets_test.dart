import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/navigation/navigation_catalog_provider.dart';
import 'package:boorusama/core/navigation/profile_management_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../posts/details/progressive_image_test_utils.dart' as images;

void main() {
  for (final showAppBar in [true, false]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Profiles honors changing shell insets, appBar=$showAppBar scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final media = ValueNotifier(
            MediaQueryData(
              size: const Size(320, 640),
              padding: const EdgeInsets.only(bottom: 104),
              viewPadding: const EdgeInsets.only(bottom: 104),
              textScaler: TextScaler.linear(scale),
            ),
          );
          addTearDown(media.dispose);
          final profiles = [
            for (var i = 0; i < 20; i++)
              BooruConfig.fromJson({
                ...BooruConfig.empty.toJson(),
                'id':
                    '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
                'name': 'Profile $i',
                'url': 'https://example.com',
              }),
          ];
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                navigationProfilesProvider.overrideWithValue(profiles),
                booruConfigProvider.overrideWith(
                  () => BooruConfigNotifier(initialConfigs: profiles),
                ),
                automaticMediaLoadingEnabledProvider.overrideWithValue(false),
                faviconDioProvider.overrideWithValue(Dio()),
                defaultImageCacheManagerProvider.overrideWithValue(
                  images.TestImageCache({}),
                ),
              ],
              child: BooruLocalization(
                child: MaterialApp(
                  builder: (context, child) => ValueListenableBuilder(
                    valueListenable: media,
                    builder: (_, data, _) => MediaQuery(
                      data: data,
                      child: child!,
                    ),
                  ),
                  home: ProfileManagementPage(showAppBar: showAppBar),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final list = find.byType(ReorderableListView);
          final scrollable = find
              .descendant(
                of: list,
                matching: find.byType(Scrollable),
              )
              .first;
          for (final (inset, keyboard) in [
            (104.0, 0.0),
            (24.0, 0.0),
            (0.0, 240.0),
            (104.0, 0.0),
          ]) {
            media.value = media.value.copyWith(
              padding: EdgeInsets.only(bottom: inset),
              viewPadding: EdgeInsets.only(bottom: inset),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            );
            await tester.pumpAndSettle();
            expect(
              tester.widget<ReorderableListView>(list).padding,
              EdgeInsets.only(bottom: inset),
            );
            await tester.scrollUntilVisible(
              find.text('Profile 19'),
              200,
              scrollable: scrollable,
            );
            final position = tester.state<ScrollableState>(scrollable).position;
            position.jumpTo(position.maxScrollExtent);
            await tester.pumpAndSettle();
            final lastRow = find.ancestor(
              of: find.text('Profile 19'),
              matching: find.byType(ListTile),
            );
            expect(
              tester.getRect(lastRow).bottom,
              lessThanOrEqualTo(tester.getRect(list).bottom - inset + 0.5),
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
