import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_read_access.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/anonymous_access_provider.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

const a = '11111111-1111-4111-8111-111111111111';
const b = '22222222-2222-4222-8222-222222222222';
BooruConfig profile(
  String id, {
  String site = 'https://danbooru.donmai.us',
  BooruType engine = BooruType.danbooru,
}) => BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: engine,
    url: site,
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': id,
});

class _Profiles extends BooruConfigNotifier {
  _Profiles(List<BooruConfig> profiles) : super(initialConfigs: profiles);
}

class _Settings extends SettingsNotifier {
  _Settings()
    : super(Settings.defaultSettings.copyWith(booruConfigIdOrders: '$b $a'));
  void order(String value) =>
      state = state.copyWith(booruConfigIdOrders: value);
}

void main() {
  for (final hint in [null, a, b, 'foreign']) {
    test('saved profile order wins over hint $hint', () {
      final profiles = [profile(a), profile(b)];
      final target = BookmarkReaderRequest(
        PostOrigin.fromSource(
          booruType: BooruType.danbooru,
          booruId: 0,
          source: profiles[0].url,
          profileIdHint: hint,
        ),
      );
      expect(
        selectBookmarkReadProfile(
          target,
          bookmarkReadProfiles(profiles, [b, 'missing', b, a]),
        )?.id,
        b,
      );
      expect(selectBookmarkReadProfile(target, []), isNull);
      expect(selectBookmarkReadProfile(target, [profiles.first])?.id, a);
    });
  }
  test('engine, path, port and proven transport must match exactly', () {
    final target = BookmarkReaderRequest(
      PostOrigin.fromSource(
        booruType: BooruType.danbooru,
        booruId: 0,
        source: 'https://host.test:8443/install',
      ),
      site: Uri.parse('https://host.test:8443/install'),
    );
    expect(
      selectBookmarkReadProfile(target, [
        profile(a, site: 'http://host.test:8443/install'),
        profile(a, site: 'https://host.test:8443/other'),
        profile(a, site: 'https://host.test/install'),
        profile(
          a,
          site: 'https://host.test:8443/install',
          engine: BooruType.gelbooru,
        ),
      ]),
      isNull,
    );
    expect(
      selectBookmarkReadProfile(target, [
        profile(b, site: 'https://host.test:8443/install'),
      ])?.id,
      b,
    );
  });
  test('registered public endpoint also requires the appropriate adapter', () {
    final container = ProviderContainer(
      overrides: [
        booruConfigProvider.overrideWith(() => _Profiles([])),
        settingsNotifierProvider.overrideWith(_Settings.new),
        booruEngineRegistryProvider.overrideWithValue(BooruEngineRegistry()),
        anonymousContentAccessProvider.overrideWith(
          (ref, source) =>
              throw StateError('No unregistered adapter can authorize access'),
        ),
      ],
    );
    addTearDown(container.dispose);
    for (final kind in ContentKind.values) {
      expect(
        container.read(
          bookmarkReadAccessProvider(
            BookmarkReaderRequest(
              PostOrigin.fromSource(
                booruType: BooruType.danbooru,
                booruId: 0,
                source: 'https://danbooru.donmai.us',
              ),
              kind: kind,
            ),
          ),
        ),
        isNull,
      );
    }
    expect(
      container.read(
        bookmarkReadAccessProvider(
          BookmarkReaderRequest(
            PostOrigin.fromSource(
              booruType: BooruType.danbooru,
              booruId: 0,
              source: 'https://private.test',
            ),
          ),
        ),
      ),
      isNull,
    );
  });
  test('a loading first reader cannot fall through to another account or anonymous', () {
    final container = ProviderContainer(
      overrides: [
        booruConfigProvider.overrideWith(
          () => _Profiles([profile(a), profile(b)]),
        ),
        settingsNotifierProvider.overrideWith(_Settings.new),
        contentEffectivePolicyProvider.overrideWith((ref, id) {
          expect(id, b);
          return const AsyncLoading();
        }),
        anonymousContentAccessProvider.overrideWith(
          (ref, source) => throw StateError('No downgrade'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final target = BookmarkReaderRequest(
      PostOrigin.fromSource(
        booruType: BooruType.danbooru,
        booruId: 0,
        source: 'https://danbooru.donmai.us',
        profileIdHint: a,
      ),
    );
    expect(container.read(bookmarkReadAccessProvider(target)), isNull);
  });
  testWidgets(
    'fresh opens follow saved order; captured viewer actor remains pinned',
    (tester) async {
      final profiles = [profile(a), profile(b)];
      final container = ProviderContainer(
        overrides: [
          booruConfigProvider.overrideWith(() => _Profiles(profiles)),
          settingsNotifierProvider.overrideWith(_Settings.new),
        ],
      );
      addTearDown(container.dispose);
      ViewerSourceBinding? fresh;
      final target = BookmarkReaderRequest(
        PostOrigin.fromSource(
          booruType: BooruType.danbooru,
          booruId: 0,
          source: profiles.first.url,
          profileIdHint: a,
        ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (_, ref, _) {
              ref.watch(bookmarkReadProfilesProvider);
              fresh = bookmarkReadBinding(ref, target);
              return const SizedBox();
            },
          ),
        ),
      );
      final captured = fresh!;
      expect(captured.config.id, b);
      (container.read(settingsNotifierProvider.notifier) as _Settings).order(
        '$a $b',
      );
      await tester.pump();
      expect(fresh!.config.id, a);
      expect(captured.resolve(profiles)?.id, b);
      expect(captured.resolve([profiles.first]), isNull);
      expect(
        captured.resolve([profile(b, site: 'https://other.test')]),
        isNull,
      );
    },
  );
}
