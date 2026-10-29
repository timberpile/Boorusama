import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart' as km;
import 'package:material_ui/material_ui.dart';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/boorus/pixiv/configs/experimental_notice.dart';
import 'package:boorusama/boorus/pixiv/pixiv.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/create/providers.dart';
import 'package:boorusama/core/configs/create/src/pages/add_booru_page.dart';
import 'package:boorusama/core/configs/create/src/pages/add_unknown_booru_page.dart';
import 'package:boorusama/core/configs/create/src/pages/unsaved_alert_dialog.dart';
import 'package:boorusama/core/configs/create/src/widgets/create_booru_config_name_field.dart';
import 'package:boorusama/core/configs/create/src/widgets/create_booru_submit_button.dart';
import 'package:boorusama/core/configs/create/src/widgets/unknown_booru_submit_button.dart';
import 'package:boorusama/core/configs/manage/src/pages/remove_booru_alert_dialog.dart';
import 'package:boorusama/core/navigation/navigation_destination_pages.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';

import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';
import 'support/application_test_store.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

const _viewport = Size(720, 1000);
const _unknownSite = 'https://unknown.booru.test/';

void main() {
  for (final signedIn in [false, true]) {
    testWidgets(
      'Pixiv editor preserves credentials on open/cancel/save ($signedIn)',
      (tester) async {
        final backend = _pixivBackend();
        final profile = BooruConfig.fromJson({
          ...BooruConfig.defaultConfig(
            booruType: BooruType.pixiv,
            url: 'https://pixiv.net/',
            customDownloadFileNameFormat: null,
          ).toJson(),
          'id': '00000000-0000-4000-8000-000000000059',
          'name': 'Pixiv fixture',
          'apiKey': signedIn ? 'synthetic-widget-test-token' : '',
          'login': signedIn ? 'fixture-account' : '',
          'passHash': signedIn ? '{"userName":"Fixture"}' : null,
        });
        final store = ApplicationTestStore.withProfiles(
          backend.config,
          additional: [profile],
        );
        final flow = await _ConfigFlow.mount(tester, backend, store);
        await flow.openEditor(profile);
        expect(find.byType(PixivExperimentalNotice), findsOneWidget);
        expect(find.text('Experimental'), findsOneWidget);
        final editor = ProviderScope.containerOf(
          tester.element(find.byType(PixivExperimentalNotice)),
        );
        final draft = editor.read(
          editBooruConfigProvider(editor.read(editBooruConfigIdProvider)),
        );
        expect(draft.apiKey, profile.apiKey ?? '');
        expect(draft.login, profile.login ?? '');
        expect(draft.passHash, profile.passHash);
        expect(
          find.text(appStrings(tester).pixiv.auth.credential_export_warning),
          findsOneWidget,
        );
        expect(store.configWithId(profile.id), profile);
        await tester.binding.handlePopRoute();
        await flow.harness.pumpUntil(
          tester,
          () => find.byType(PixivExperimentalNotice).evaluate().isEmpty,
          description: 'Pixiv editor to close',
        );
        expect(find.byType(PixivExperimentalNotice), findsNothing);
        expect(store.configWithId(profile.id), profile);
        await flow.openEditor(profile);
        await flow.setProfileName('Renamed Pixiv');
        await tester.tap(find.byType(CreateBooruSubmitButton));
        await flow.harness.pumpUntil(
          tester,
          () => store.configWithId(profile.id).name == 'Renamed Pixiv',
          description: 'Pixiv edit saved',
        );
        final saved = store.configWithId(profile.id);
        expect(saved.auth.apiKey, profile.auth.apiKey);
        expect(saved.auth.login, profile.auth.login);
        expect(saved.auth.passHash, profile.auth.passHash);
        await flow.openEditor(backend.config);
        expect(find.byType(PixivExperimentalNotice), findsNothing);
      },
    );
  }

  testWidgets(
    'new Pixiv route shows one notice and can cancel without creating a profile',
    (tester) async {
      final backend = _pixivBackend();
      final store = ApplicationTestStore.withProfiles(backend.config);
      final flow = await _ConfigFlow.mount(tester, backend, store);
      await flow.driver.openProfiles();
      await tester.tap(find.text(appStrings(tester).generic.action.add));
      await flow.harness.pumpUntilFound(tester, find.text('Pixiv'));
      await flow.harness.pumpUntil(
        tester,
        () =>
            ModalRoute.of(tester.element(find.text('Pixiv')))!
                .animation!
                .status ==
            AnimationStatus.completed,
        description: 'quick-profile route animation to finish',
      );
      await tester.tap(find.text('Pixiv'));
      await flow.harness.pumpUntilFound(
        tester,
        find.byType(PixivExperimentalNotice),
      );
      expect(find.byType(PixivExperimentalNotice), findsOneWidget);
      expect(
        find.text(appStrings(tester).pixiv.auth.credential_export_warning),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await flow.harness.settle(tester);
      if (find.byType(UnsavedAlertDialog).evaluate().isNotEmpty) {
        await tester.tap(
          find.text(appStrings(tester).booru.unsaved_changes_discard),
        );
      }
      await flow.harness.pumpUntil(
        tester,
        () => find.byType(PixivExperimentalNotice).evaluate().isEmpty,
        description: 'new Pixiv editor to close',
      );
      expect(store.configs, [backend.config]);
    },
  );

  testWidgets('creates, activates, edits, and restores a saved profile', (
    tester,
  ) async {
    final backend = FakeBooruBackend(strictPostScripts: true)
      ..enqueuePosts(page: 1, posts: [TestPost(id: 101)]);
    for (var i = 0; i < 3; i++) {
      backend.enqueuePosts(
        siteUrl: FakeBooruBackend.secondSiteUrl,
        page: 1,
        posts: [
          TestPost(id: 101, tags: const {'profile_b_marker'}),
        ],
      );
    }
    final store = ApplicationTestStore.withProfiles(backend.config);
    final flow = await _ConfigFlow.mount(tester, backend, store);

    await flow.waitForListing();
    await flow.driver.openAddProfile();
    await flow.submitUrl(FakeBooruBackend.secondSiteUrl);
    await flow.setProfileName('Profile B');
    await tester.tap(find.byType(CreateBooruSubmitButton));
    await flow.harness.pumpUntil(
      tester,
      () => store.configs.length == 2,
      description: 'new profile B to be written',
    );
    final profileB = store.configs.singleWhere(
      (config) => config.url == FakeBooruBackend.secondSiteUrl,
    );
    expect(profileB.name, 'Profile B');
    expect(profileB.id, isNot(backend.config.id));

    await flow.driver.selectProfile(profileB);
    await flow.harness.pumpUntilFound(
      tester,
      listingPostWithTag('profile_b_marker'),
    );
    expect(store.settings.currentBooruConfigId, profileB.id);
    expect(flow.postRequests.last.siteUrl, FakeBooruBackend.secondSiteUrl);

    await flow.openEditor(profileB);
    await flow.setProfileName('Edited B');
    await flow.toggleProfileSpecificListing();
    await tester.tap(find.byType(CreateBooruSubmitButton));
    await flow.harness.pumpUntil(
      tester,
      () => store.configWithId(profileB.id).name == 'Edited B',
      description: 'edited profile B to update in place',
    );
    expect(store.configWithId(profileB.id).listing?.enable, isTrue);
    expect(store.configs, hasLength(2));

    final requestsBeforeRemount = flow.postRequests.length;
    final remounted = await flow.remount();
    await remounted.harness.pumpUntil(
      tester,
      () => remounted.postRequests.length > requestsBeforeRemount,
      description: 'remounted listing to reload from persisted selection',
    );
    expect(remounted.postRequests.last.siteUrl, profileB.url);
    expect(
      remounted.harness.runtime.initialState.initialConfig.id,
      profileB.id,
    );

    await remounted.openEditor(profileB);
    expect(remounted.profileName, 'Edited B');
  });

  testWidgets('rejects malformed URLs before creating a profile', (
    tester,
  ) async {
    final backend = FakeBooruBackend();
    final store = ApplicationTestStore.withProfiles(backend.config);
    final flow = await _ConfigFlow.mount(tester, backend, store);

    await flow.driver.openAddProfile();
    const malformed = 'ftp://invalid.test/';
    await tester.enterText(flow.urlInput, malformed);
    await tester.pump();

    final strings = appStrings(tester);
    expect(
      find.text(
        strings.booru.validation_invalid_http_url.replaceAll('{0}', malformed),
      ),
      findsOneWidget,
    );
    expect(flow.nextButton.onPressed, isNull);
    expect(store.configs, [backend.config]);

    await flow.submitUrl(FakeBooruBackend.secondSiteUrl);
    await flow.setProfileName('Corrected profile');
    await tester.tap(find.byType(CreateBooruSubmitButton));
    await flow.harness.pumpUntil(
      tester,
      () => store.configs.length == 2,
      description: 'corrected URL profile to be saved',
    );
    expect(
      store.configs.where((c) => c.url == FakeBooruBackend.secondSiteUrl),
      hasLength(1),
    );
  });

  final unsavedChoices = [
    (choice: 'discard', storedName: 'Saved B'),
    (choice: 'save', storedName: 'Unsaved B'),
  ];
  for (final c in unsavedChoices) {
    testWidgets(
      'choosing ${c.choice} for an unsaved edit stores "${c.storedName}"',
      (tester) async {
        final backend = FakeBooruBackend();
        final profileB = backend.configB.copyWith(name: 'Saved B');
        final store = ApplicationTestStore.withProfiles(
          backend.config,
          additional: [profileB],
        );
        final flow = await _ConfigFlow.mount(tester, backend, store);

        await flow.openEditor(profileB);
        await flow.setProfileName('Unsaved B');
        await tester.binding.handlePopRoute();
        await flow.harness.pumpUntilFound(
          tester,
          find.byType(UnsavedAlertDialog),
        );
        await tester.pump(const Duration(milliseconds: 500));

        final strings = appStrings(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(UnsavedAlertDialog),
            matching: find.text(switch (c.choice) {
              'save' => strings.generic.action.save,
              _ => strings.booru.unsaved_changes_discard,
            }),
          ),
        );
        await flow.harness.pumpUntil(
          tester,
          () =>
              find.byType(BooruConfigNameField).evaluate().isEmpty &&
              store.configWithId(profileB.id).name == c.storedName,
          description: 'editor to close with "${c.storedName}" stored',
        );
        expect(store.configs, hasLength(2));

        await flow.openEditor(profileB);
        expect(flow.profileName, c.storedName);
      },
    );
  }

  testWidgets(
    'cancels then confirms active profile deletion and restores fallback',
    (tester) async {
      final backend = FakeBooruBackend(strictPostScripts: true);
      final profileB = backend.configB.copyWith(name: 'Profile B');
      for (var i = 0; i < 3; i++) {
        backend.enqueuePosts(page: 1, posts: [backend.posts.first]);
      }
      backend.enqueuePosts(
        siteUrl: profileB.url,
        page: 1,
        posts: [backend.postsB.first],
      );
      final store = ApplicationTestStore.withProfiles(
        backend.config,
        additional: [profileB],
      );
      final flow = await _ConfigFlow.mount(tester, backend, store);

      await flow.driver.selectProfile(profileB);
      await flow.requestDeletion(profileB);
      await tester.tap(find.text(appStrings(tester).generic.action.cancel));
      await flow.harness.pumpUntil(
        tester,
        () => find.byType(RemoveBooruConfigAlertDialog).evaluate().isEmpty,
        description: 'deletion dialog to close after cancel',
      );
      expect(store.configs, hasLength(2));
      expect(store.settings.currentBooruConfigId, profileB.id);

      await flow.requestDeletion(profileB);
      final requestsBeforeConfirm = flow.postRequests.length;
      await flow.confirmDeletion();
      await flow.harness.pumpUntil(
        tester,
        () =>
            store.configs.length == 1 &&
            store.settings.currentBooruConfigId == backend.config.id,
        description: 'deleting active profile B to select profile A',
      );
      expect(
        flow.postRequests.length,
        requestsBeforeConfirm,
        reason: 'profile management does not start requests in a hidden Browse branch',
      );
      await flow.driver.selectProfile(backend.config);
      expect(store.configs.single.id, backend.config.id);

      final remounted = await flow.remount();
      await remounted.waitForListing();
      expect(
        remounted.harness.runtime.initialState.initialConfig.id,
        backend.config.id,
      );
      expect(store.configs, hasLength(1));
    },
  );

  testWidgets('deleting the last profile persists the empty setup state', (
    tester,
  ) async {
    final backend = FakeBooruBackend();
    final store = ApplicationTestStore.withProfiles(backend.config);
    final flow = await _ConfigFlow.mount(tester, backend, store);

    await flow.requestDeletion(backend.config);
    await flow.confirmDeletion();
    await flow.harness.pumpUntil(
      tester,
      () => store.configs.isEmpty,
      description: 'last profile to be removed from persisted configs',
    );
    expect(store.settings.booruConfigIdOrders, isEmpty);
    expect(
      store.configs.map((config) => config.id),
      isNot(contains(store.settings.currentBooruConfigId)),
    );

    final remounted = await flow.remount();
    expect(
      remounted.harness.runtime.initialState.initialConfig,
      BooruConfig.empty,
    );
    expect(store.configs, isEmpty);
    expect(find.byType(NavigationRecoveryPage), findsOneWidget);
    expect(find.byKey(const ValueKey('empty-profile-add')), findsOneWidget);
    expect(find.text(appStrings(tester).booru.add_profile), findsOneWidget);
    expect(find.byKey(const ValueKey('empty-profile-import')), findsOneWidget);
  });

  testWidgets(
    'a failed connection check warns and a later successful check confirms',
    (tester) async {
      final backend = FakeBooruBackend()
        ..enqueueSiteValidation(_unknownSite, FakeSiteValidation.unreachable)
        ..enqueueSiteValidation(_unknownSite, FakeSiteValidation.reachable);
      final store = ApplicationTestStore.withProfiles(backend.config);
      final flow = await _ConfigFlow.mount(tester, backend, store);

      await flow.startUnknownSiteProfile('Unknown site');
      await flow.tapUnknownSiteSubmit();
      final strings = appStrings(tester);
      await flow.harness.pumpUntilFound(
        tester,
        find.text(strings.booru.invalid_booru_warning),
      );
      expect(backend.siteValidations.map((v) => v.siteUrl), [_unknownSite]);
      expect(flow.unknownSiteSubmitLabel, strings.generic.action.verify);
      expect(store.configs, [backend.config]);

      await flow.tapUnknownSiteSubmit();
      await flow.harness.pumpUntil(
        tester,
        () => flow.unknownSiteSubmitLabel == strings.booru.config_booru_confirm,
        description: 'successful recheck to offer confirmation',
      );
      expect(find.text(strings.booru.invalid_booru_warning), findsNothing);
      expect(backend.siteValidations, hasLength(2));

      await flow.tapUnknownSiteSubmit();
      await flow.harness.pumpUntil(
        tester,
        () => store.configs.length == 2,
        description: 'confirmed unknown-site profile to be saved',
      );
      final saved = store.configs.last;
      expect(saved.url, _unknownSite);
      expect(saved.name, 'Unknown site');
      expect(saved.auth.booruIdHint, BooruType.danbooru.id);
    },
  );

  testWidgets(
    'an empty-results connection check warns but still allows saving',
    (tester) async {
      final backend = FakeBooruBackend()
        ..enqueueSiteValidation(_unknownSite, FakeSiteValidation.emptyResults);
      final store = ApplicationTestStore.withProfiles(backend.config);
      final flow = await _ConfigFlow.mount(tester, backend, store);

      await flow.startUnknownSiteProfile('Empty site');
      await flow.tapUnknownSiteSubmit();
      await flow.harness.pumpUntilFound(tester, find.text('Empty results'));
      expect(backend.siteValidations.map((v) => v.siteUrl), [_unknownSite]);
      expect(store.configs, [backend.config]);

      await flow.tapUnknownSiteSubmit();
      await flow.harness.pumpUntil(
        tester,
        () => store.configs.length == 2,
        description: 'profile to be saved despite empty check results',
      );
      expect(store.configs.last.url, _unknownSite);
      expect(backend.siteValidations, hasLength(1));
    },
  );
}

FakeBooruBackend _pixivBackend() => FakeBooruBackend(
  additionalBoorus: {
    BooruType.pixiv: createPixiv().parser.parse(),
  },
)..registry.register(BooruType.pixiv, createPixiv());

final class _ConfigFlow {
  _ConfigFlow._(this.tester, this.store, this.harness)
    : driver = AppFlowDriver(tester: tester, harness: harness);

  static Future<_ConfigFlow> mount(
    WidgetTester tester,
    FakeBooruBackend backend,
    ApplicationTestStore store,
  ) async {
    final harness = await store.mount(
      tester,
      backend: backend,
      viewportSize: _viewport,
    );
    return _ConfigFlow._(tester, store, harness);
  }

  final WidgetTester tester;
  final ApplicationTestStore store;
  final HeadlessAppHarness harness;
  final AppFlowDriver driver;

  List<FakeBooruPostRequest> get postRequests =>
      harness.booruBackend.requests.whereType<FakeBooruPostRequest>().toList();

  Finder get urlInput => find.descendant(
    of: find.byType(AddBooruPageInternal),
    matching: find.byType(EditableText),
  );

  km.FilledButton get nextButton => tester.widget<km.FilledButton>(
    find
        .ancestor(
          of: find.text(appStrings(tester).booru.next_step),
          matching: find.byType(km.FilledButton),
        )
        .last,
  );

  Finder get _profileNameInput => find.descendant(
    of: find.byType(BooruConfigNameField),
    matching: find.byType(EditableText),
  );

  String get profileName =>
      tester.widget<EditableText>(_profileNameInput).controller.text;

  Future<_ConfigFlow> remount() async {
    final next = await store.remount(tester, previous: harness);
    return _ConfigFlow._(tester, store, next);
  }

  Future<void> waitForListing() => harness.pumpUntilFound(
    tester,
    find.byType(SliverPostGridImageGridItem),
  );

  Future<void> submitUrl(String url) async {
    if (urlInput.evaluate().isEmpty) {
      await tester.tap(
        find.text(appStrings(tester).booru.quick_setup.custom_site),
      );
      await harness.pumpUntilFound(tester, urlInput);
    }
    await tester.enterText(urlInput, url);
    await tester.pump();
    expect(nextButton.onPressed, isNotNull);
    await tester.tap(find.text(appStrings(tester).booru.next_step).last);
    await tester.pump();
  }

  Future<void> setProfileName(String value) async {
    await harness.pumpUntilFound(tester, _profileNameInput);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(_profileNameInput, value);
    await tester.pump();
  }

  Future<void> openEditor(BooruConfig config) async {
    await driver.openProfileMenu(config);
    await tester.tap(find.text(appStrings(tester).generic.action.edit));
    await tester.pump();
    await harness.pumpUntilFound(tester, find.byType(BooruConfigNameField));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> toggleProfileSpecificListing() async {
    final strings = appStrings(tester);
    await tester.tap(find.text(strings.booru.listing.title).first);
    await tester.pump();
    final setting = find.text(
      strings.booru.listing.enable_profile_specific_settings,
    );
    await harness.pumpUntilFound(tester, setting);
    await tester.tap(setting);
    await tester.pump();
  }

  Future<void> requestDeletion(BooruConfig config) async {
    await driver.openProfileMenu(config);
    await tester.tap(find.text(appStrings(tester).generic.action.delete));
    await tester.pump();
    await harness.pumpUntilFound(
      tester,
      find.byType(RemoveBooruConfigAlertDialog),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> confirmDeletion() async {
    await tester.tap(
      find.descendant(
        of: find.byType(RemoveBooruConfigAlertDialog),
        matching: find.byType(km.FilledButton),
      ),
    );
    await tester.pump();
  }

  Future<void> startUnknownSiteProfile(String name) async {
    await driver.openAddProfile();
    await submitUrl(_unknownSite);
    await harness.pumpUntilFound(tester, find.byType(AddUnknownBooruPage));

    await tester.tap(find.byType(KurumiOptionDropDownButton<BooruType?>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(BooruType.danbooru.displayName).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await setProfileName(name);
  }

  Finder get _unknownSiteSubmit => find.descendant(
    of: find.byType(UnknownBooruSubmitButton),
    matching: find.byType(CreateBooruSubmitButton),
  );

  String? get unknownSiteSubmitLabel => tester
      .widgetList<Text>(
        find.descendant(of: _unknownSiteSubmit, matching: find.byType(Text)),
      )
      .firstOrNull
      ?.data;

  Future<void> tapUnknownSiteSubmit() async {
    await tester.ensureVisible(_unknownSiteSubmit);
    await tester.pump();
    await tester.tap(_unknownSiteSubmit);
    await tester.pump();
    await tester.pump();
  }
}
