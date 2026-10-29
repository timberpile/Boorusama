import 'package:boorusama/core/posts/details_parts/src/toolbars/customizable_post_toolbar.dart';
import 'package:boorusama/core/widgets/adaptive_button_row.dart';
import 'package:boorusama/core/widgets/booru_menu_button_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  Widget wrap(Widget child) => ProviderScope(
    child: BooruLocalization(
      child: MaterialApp(
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: child),
        ),
      ),
    ),
  );

  testWidgets('narrow width moves outer actions into an executable menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ViewerToolbarAction? invoked;
    final layout = ViewerToolbarLayout.editorDefault();
    await tester.pumpWidget(
      wrap(
        ConfiguredPostToolbar(
          layout: layout,
          buttons: [
            for (final id in ViewerToolbarAction.values)
              ViewerToolbarSimpleButtonData(
                action: id,
                icon: Icons.star,
                title: id.name,
                onPressed: () => invoked = id,
              ),
            SimpleButtonData(
              icon: Icons.settings,
              title: 'Settings',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    expect(find.byKey(const Key('viewer-toolbar-comments')), findsNothing);
    expect(find.byKey(const Key('viewer-toolbar-bookmark')), findsOneWidget);
    await tester.tap(find.byKey(const Key('viewer-toolbar-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('viewer-toolbar-menu-comments')));
    await tester.pumpAndSettle();
    expect(invoked, ViewerToolbarAction.comments);
    expect(layout.toolbar.first, ViewerToolbarAction.comments);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing engine actions do not leave holes or mutate preferences',
    (tester) async {
      final layout = ViewerToolbarLayout.editorDefault();
      await tester.pumpWidget(
        wrap(
          ConfiguredPostToolbar(
            layout: layout,
            buttons: [
              ViewerToolbarSimpleButtonData(
                action: ViewerToolbarAction.bookmark,
                icon: Icons.bookmark,
                title: 'Bookmark',
                onPressed: () {},
              ),
              ViewerToolbarSimpleButtonData(
                action: ViewerToolbarAction.share,
                icon: Icons.share,
                title: 'Share',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.byKey(const Key('viewer-toolbar-favorite')), findsNothing);
      expect(find.byKey(const Key('viewer-toolbar-bookmark')), findsOneWidget);
      expect(layout.toolbar, contains(ViewerToolbarAction.favorite));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all-More layout retains specialized menu builders and fixed actions',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(
          ConfiguredPostToolbar(
            layout: ViewerToolbarLayout(toolbar: const []),
            buttons: [
              ViewerToolbarButtonData(
                action: ViewerToolbarAction.download,
                title: 'Download',
                widget: const Icon(Icons.download),
                menuBuilder: (_, close) => TextButton(
                  onPressed: () {
                    tapped = true;
                    close();
                  },
                  child: const Text('Download with quality'),
                ),
              ),
              SimpleButtonData(
                title: 'Settings',
                icon: Icons.settings,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('viewer-toolbar-more')));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      await tester.tap(find.text('Download with quality'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
      expect(find.text('Download with quality'), findsNothing);
    },
  );
  testWidgets('no preference retains the existing engine toolbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [viewerToolbarLayoutProvider.overrideWithValue(null)],
        child: wrap(
          CustomizablePostToolbar(
            maxVisibleButtons: 4,
            buttons: [
              ViewerToolbarSimpleButtonData(
                action: ViewerToolbarAction.bookmark,
                title: 'Bookmark',
                icon: Icons.bookmark,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(BooruMenuButtonRow), findsOneWidget);
    expect(find.byType(ConfiguredPostToolbar), findsNothing);
  });

  testWidgets('menu consumers retain the source profile provider scope', (
    tester,
  ) async {
    final account = Provider<String>(
      (ref) => 'global-account',
      dependencies: const [],
    );
    await tester.pumpWidget(
      wrap(
        ProviderScope(
          overrides: [account.overrideWithValue('source-account')],
          child: ConfiguredPostToolbar(
            layout: ViewerToolbarLayout(toolbar: const []),
            buttons: [
              ViewerToolbarButtonData(
                action: ViewerToolbarAction.share,
                title: 'Share',
                widget: const Icon(Icons.share),
                menuBuilder: (_, _) => Consumer(
                  builder: (_, ref, _) => Text(ref.watch(account)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('viewer-toolbar-more')));
    await tester.pumpAndSettle();
    expect(find.text('source-account'), findsOneWidget);
    expect(find.text('global-account'), findsNothing);
  });
  testWidgets('rebuilding action callbacks dismisses the old menu', (
    tester,
  ) async {
    final generation = ValueNotifier(0);
    addTearDown(generation.dispose);
    await tester.pumpWidget(
      wrap(
        ValueListenableBuilder(
          valueListenable: generation,
          builder: (_, value, _) => ConfiguredPostToolbar(
            layout: ViewerToolbarLayout(toolbar: const []),
            buttons: [
              ViewerToolbarSimpleButtonData(
                action: ViewerToolbarAction.favorite,
                icon: Icons.favorite,
                title: 'Favorite $value',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('viewer-toolbar-more')));
    await tester.pumpAndSettle();
    expect(find.text('Favorite 0'), findsOneWidget);
    generation.value++;
    await tester.pumpAndSettle();
    expect(find.text('Favorite 0'), findsNothing);
    await tester.tap(find.byKey(const Key('viewer-toolbar-more')));
    await tester.pumpAndSettle();
    expect(find.text('Favorite 1'), findsOneWidget);
  });

  testWidgets('a nested quality menu stays open until selection', (
    tester,
  ) async {
    final quality = AnchorController();
    addTearDown(quality.dispose);
    var calls = 0;
    await tester.pumpWidget(
      wrap(
        ConfiguredPostToolbar(
          layout: ViewerToolbarLayout(toolbar: const []),
          buttons: [
            ViewerToolbarButtonData(
              action: ViewerToolbarAction.download,
              title: 'Download',
              widget: const Icon(Icons.download),
              menuBuilder: (_, close) => KurumiAnchor(
                controller: quality,
                overlayBuilder: (_) => SizedBox(
                  width: 160,
                  child: KurumiPopupMenuItem(
                    title: const Text('Original quality'),
                    onTap: () {
                      calls++;
                      close();
                    },
                  ),
                ),
                child: TextButton(
                  onPressed: quality.show,
                  child: const Text('Quality'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('viewer-toolbar-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quality'));
    await tester.pumpAndSettle();
    expect(find.text('Original quality'), findsOneWidget);
    await tester.tap(find.text('Original quality'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Quality'), findsNothing);
    expect(find.text('Original quality'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0, 440.0]) {
    for (final direction in TextDirection.values) {
      testWidgets('$width dp, 200% text, keyboard and $direction retain More', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 360);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 100),
                ),
                child: Directionality(
                  textDirection: direction,
                  child: ConfiguredPostToolbar(
                    layout: ViewerToolbarLayout.editorDefault(),
                    buttons: [
                      for (final id in ViewerToolbarAction.values)
                        ViewerToolbarSimpleButtonData(
                          action: id,
                          icon: Icons.star,
                          title: id.name,
                          onPressed: () {},
                        ),
                      SimpleButtonData(
                        icon: Icons.settings,
                        title: 'Settings',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getCenter(find.byKey(const Key('viewer-toolbar-more'))).dx,
          greaterThan(width - 60),
        );
        await tester.tap(find.byKey(const Key('viewer-toolbar-more')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Settings'));
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
