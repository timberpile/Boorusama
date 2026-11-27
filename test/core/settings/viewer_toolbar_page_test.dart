import 'package:boorusama/boorus/danbooru/danbooru_builder.dart';
import 'package:boorusama/boorus/szurubooru/szurubooru_builder.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/config_widgets/website_logo.dart';
import 'package:boorusama/core/configs/config/data.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/settings/src/pages/viewer_toolbar_layout_page.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/settings/src/types/viewer_toolbar_layout.dart';
import 'package:boorusama/core/settings/src/widgets/viewer_toolbar_editor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../search/following_topics/following_topic_test_utils.dart';

final _signed = _profile(
  testProfile,
  'Signed in',
  login: true,
  icon: 'https://icons.example/custom.png',
);
final _guest = _profile(otherTestProfile, 'Guest');
final _szuru = _profile(
  testProfile,
  'Szurubooru',
  login: true,
  type: BooruType.szurubooru,
);
final _layout = ViewerToolbarLayout(
  toolbar: const [ViewerToolbarAction.upvote, ViewerToolbarAction.bookmark],
);

BooruConfig _profile(
  BooruConfig fixture,
  String name, {
  BooruType type = BooruType.danbooru,
  bool login = false,
  String? icon,
}) => BooruConfig.fromJson({
  ...fixture.toJson(),
  'name': name,
  'booruId': type.id,
  'booruIdHint': type.id,
  'login': login ? 'user' : null,
  'apiKey': login ? 'fixture' : null,
  if (icon != null) 'profileIcon': {'url': icon},
});

class _Store implements BooruConfigRepository {
  _Store(List<BooruConfig> profiles)
    : profiles = {for (final profile in profiles) profile.id: profile};
  final Map<String, BooruConfig> profiles;
  var writes = 0;
  var fail = false;

  @override
  Future<List<BooruConfig>> getAll() async => profiles.values.toList();

  @override
  Future<BooruConfig?> update(
    String id,
    BooruConfigData booruConfigData,
  ) async {
    writes++;
    if (fail) return null;
    final profile = booruConfigData.toBooruConfig(id: id)!;
    return profiles[id] = profile;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const apply = Key('toolbar-apply');
  const picker = Key('toolbar-profile-picker');

  Future<_Store> mount(WidgetTester tester, List<BooruConfig> profiles) async {
    final store = _Store(profiles);
    final harness = FollowingTopicHarness(
      profiles: profiles,
      profileRepository: store,
      booruBuilder: (auth) => switch (auth.booruType) {
        BooruType.danbooru => DanbooruBuilder(),
        BooruType.szurubooru => SzurubooruBuilder(),
        _ => null,
      },
      overrides: [
        faviconDioProvider.overrideWith((ref) {
          final dio = Dio();
          ref.onDispose(dio.close);
          return dio;
        }),
      ],
    );
    addTearDown(harness.dispose);
    await harness.pump(tester, const ViewerToolbarLayoutPage());
    return store;
  }

  void reorder(WidgetTester tester) {
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(0, 1);
  }

  Future<void> select(WidgetTester tester, BooruConfig profile) async {
    await tester.tap(find.byKey(picker));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('toolbar-profile-${profile.id}')));
    await tester.pumpAndSettle();
  }

  Iterable<String> availableActionNames(WidgetTester tester) => tester
      .widget<ViewerToolbarEditor>(find.byType(ViewerToolbarEditor))
      .availableActions
      .map((action) => action.name);

  testWidgets('Edit is configurable for signed-in Danbooru profiles', (
    tester,
  ) async {
    await mount(tester, [_signed, _guest]);
    expect(availableActionNames(tester), contains('edit'));
    await select(tester, _guest);
    expect(availableActionNames(tester), isNot(contains('edit')));
  });

  testWidgets('each profile gets its own draft, icons and saved order', (
    tester,
  ) async {
    final store = await mount(tester, [_signed, _guest]);
    final logo = tester.widget<ConfigAwareWebsiteLogo>(
      find.byType(ConfigAwareWebsiteLogo),
    );
    expect(logo.customIconUrl, _signed.profileIcon?.url);
    final vote = find.byKey(const ValueKey(ViewerToolbarAction.upvote));
    expect(vote, findsOneWidget);
    reorder(tester);
    await tester.pump();
    await select(tester, _guest);
    expect(find.text('You have unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.writes, 0);
    expect(vote, findsOneWidget);
    await select(tester, _guest);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(vote, findsNothing);
    final signedOrder =
        store.profiles[_signed.id]!.viewerConfigs!.toolbarLayout!;
    expect(store.profiles[_guest.id]!.viewerConfigs?.toolbarLayout, isNull);
    expect(signedOrder.toolbar.first, ViewerToolbarAction.upvote);
    reorder(tester);
    await tester.pump();
    await tester.tap(find.byKey(apply));
    await tester.pumpAndSettle();
    expect(store.writes, 2);
    expect(
      store.profiles[_signed.id]!.viewerConfigs!.toolbarLayout,
      signedOrder,
    );
    expect(
      store.profiles[_guest.id]!.viewerConfigs!.toolbarLayout,
      isNot(signedOrder),
    );
  });

  testWidgets('Reset on the selected profile preserves its image options', (
    tester,
  ) async {
    final profile = _signed.copyWith(
      viewerConfigs: () => ViewerConfigs.undefined().copyWith(
        enable: true,
        toolbarLayout: () => _layout,
      ),
    );
    final store = await mount(tester, [profile, _guest]);
    await tester.scrollUntilVisible(
      find.byKey(const Key('toolbar-reset')),
      300,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toolbar-reset')));
    await tester.pumpAndSettle();
    expect(store.writes, 1);
    expect(store.profiles[profile.id]!.viewerConfigs!.enable, isTrue);
    expect(store.profiles[profile.id]!.viewerConfigs!.toolbarLayout, isNull);
  });

  testWidgets(
    'newer same-profile layout and unrelated settings survive Apply',
    (tester) async {
      final store = await mount(tester, [_signed]);
      reorder(tester);
      await tester.pump();
      store.profiles[_signed.id] = _signed.copyWith(
        viewerConfigs: () =>
            ViewerConfigs.undefined().copyWith(toolbarLayout: () => _layout),
      );
      await tester.tap(find.byKey(apply));
      await tester.pumpAndSettle();
      expect(store.writes, 0);
      expect(store.profiles[_signed.id]!.viewerConfigs!.toolbarLayout, _layout);
      expect(tester.widget<IconButton>(find.byKey(apply)).onPressed, isNotNull);
    },
  );

  testWidgets(
    'Szurubooru exposes its vote actions without Danbooru tag history',
    (tester) async {
      await mount(tester, [_szuru]);
      expect(
        find.byKey(const ValueKey(ViewerToolbarAction.upvote)),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey(ViewerToolbarAction.downvote)),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey(ViewerToolbarAction.tagHistory)),
        findsNothing,
      );
      expect(availableActionNames(tester), isNot(contains('edit')));
    },
  );
}
