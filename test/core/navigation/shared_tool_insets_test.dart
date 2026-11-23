import 'package:boorusama/core/posts/pools/src/widgets/pool_paged_sliver_grid.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/users/widgets.dart';
import 'package:boorusama/core/themes/colors/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final pool in [false, true]) {
      for (final outerSafeArea in pool ? [false, true] : [false]) {
        testWidgets(
          '${pool ? 'Pool grid' : 'User details'} keeps its last action clear at $scale text with outer safe area=$outerSafeArea',
          (tester) async {
            tester.view.physicalSize = const Size(320, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  imageListingSettingsProvider.overrideWithValue(
                    Settings.defaultSettings.listing,
                  ),
                ],
                child: BooruLocalization(
                  child: MaterialApp(
                    theme: Kurumi.themeFrom(
                      KurumiThemeMode.light,
                      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                      systemDarkMode: false,
                    ).withBoorusamaColors(),
                    builder: (context, child) => KurumiTheme(
                      data: KurumiThemeData.fromMaterial(Theme.of(context)),
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          padding: const EdgeInsets.only(bottom: 104),
                          textScaler: TextScaler.linear(scale),
                        ),
                        child: child!,
                      ),
                    ),
                    home: pool
                        ? Scaffold(
                            body: SafeArea(
                              top: false,
                              bottom: outerSafeArea,
                              child: LayoutBuilder(
                                builder: (context, constraints) =>
                                    CustomScrollView(
                                      slivers: [
                                        PoolPagedSliverGridView<int>(
                                          constraints: constraints,
                                          fetchPage: (ref, page) async =>
                                              page == 1
                                              ? List.generate(20, (i) => i)
                                              : [],
                                          imageBuilder: (context, value) =>
                                              const SizedBox(),
                                          onTap: (ref, value) {},
                                          total: (value) => 1,
                                          name: (value) => 'Pool $value',
                                        ),
                                      ],
                                    ),
                              ),
                            ),
                          )
                        : const UserDetailsPage(
                            body: UserDetailsViewScaffold(
                              sliverInfoOverview: SliverToBoxAdapter(
                                child: SizedBox(height: 1200),
                              ),
                              body: Align(
                                alignment: Alignment.bottomCenter,
                                child: Text('Last user action'),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final last = find.text(pool ? 'Pool 19' : 'Last user action');
            await tester.scrollUntilVisible(
              last,
              200,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            final scroll = tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
            scroll.jumpTo(scroll.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(last.hitTestable(), findsOneWidget);
            expect(
              tester.getRect(last).bottom,
              closeTo(536 - (pool ? 2 : 0), 0.5),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
