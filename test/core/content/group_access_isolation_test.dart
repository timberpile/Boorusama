import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/content/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String pid(String label) =>
    '00000000-0000-4000-8000-${{'a': 1, 'b': 2, 'other': 3}[label]!.toString().padLeft(12, '0')}';

BooruConfig profile(
  String id, {
  String apiKey = 'fixture',
  String site = 'http://example.test:8080/booru',
}) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': pid(id),
  'booruId': 1,
  'booruIdHint': 1,
  'url': site,
  'login': 'fixture',
  'apiKey': apiKey,
});
final policy = StateProvider((ref) => 'visibility:one');

class Configs extends BooruConfigNotifier {
  Configs() : super(initialConfigs: []);
  void replace(List<BooruConfig> values) => state = values;
}

void main() {
  final group = const ContentReferenceCodec().parse(
    engine: BooruType.danbooru,
    site: Uri.parse('http://example.test:8080/booru'),
    kind: ContentKind.group,
    sourceKey: 'pool:42',
  );
  ProviderContainer container() => ProviderContainer(
    overrides: [
      booruConfigProvider.overrideWith(Configs.new),
      contentEffectivePolicyProvider.overrideWith(
        (ref, config) => AsyncData(ref.watch(policy)),
      ),
    ],
  );

  test('access resolution reuses origin hints without borrowing an arbitrary account', () {
    final c = container();
    addTearDown(c.dispose);
    final configs = c.read(booruConfigProvider.notifier) as Configs;
    configs.replace([profile('a'), profile('b')]);
    expect(
      c.read(
        contentAccessForReferenceProvider(
          ContentAccessRequest(reference: group),
        ),
      ),
      isNull,
    );
    final a = c.read(
      contentAccessForReferenceProvider(
        ContentAccessRequest(reference: group, profileIdHint: pid('a')),
      ),
    )!;
    final b = c.read(
      contentAccessForReferenceProvider(
        ContentAccessRequest(reference: group, profileIdHint: pid('b')),
      ),
    )!;
    expect(a.key, isNot(b.key));
    expect(a.baseUrl.toString(), 'http://example.test:8080/booru');
    expect(a.key.toString(), isNot(contains('fixture')));
    expect(a.key.siteNamespace, group.siteNamespace);
    configs.replace([profile('b')]);
    expect(
      c
          .read(
            contentAccessForReferenceProvider(
              ContentAccessRequest(reference: group, profileIdHint: pid('a')),
            ),
          )!
          .key
          .profileId,
      pid('b'),
    );
    expect(a.matchesProfiles([profile('b')]), isFalse);
    configs.replace([profile('other', site: 'https://unrelated.test')]);
    expect(
      c.read(
        contentAccessForReferenceProvider(
          ContentAccessRequest(reference: group),
        ),
      ),
      isNull,
    );
  });

  test('auth and effective policy revisions revoke old keys, including remove/readd', () {
    final c = container();
    addTearDown(c.dispose);
    final configs = c.read(booruConfigProvider.notifier) as Configs;
    configs.replace([profile('a')]);
    final request = ContentAccessRequest(reference: group);
    final first = c.read(contentAccessForReferenceProvider(request))!;
    configs.replace([profile('a', apiKey: 'replacement-secret')]);
    final second = c.read(contentAccessForReferenceProvider(request))!;
    expect(second.key.authEpoch, isNot(first.key.authEpoch));
    expect(c.read(contentAccessContextProvider(first.key)), isNull);
    expect(second.key.toString(), isNot(contains('replacement-secret')));
    c.read(policy.notifier).state = 'visibility:two';
    final third = c.read(contentAccessForReferenceProvider(request))!;
    expect(third.key.authEpoch, second.key.authEpoch);
    expect(third.key.policyEpoch, isNot(second.key.policyEpoch));
    expect(c.read(contentAccessContextProvider(second.key)), isNull);
    configs.replace([]);
    expect(c.read(contentAccessContextProvider(third.key)), isNull);
    configs.replace([profile('a', apiKey: 'replacement-secret')]);
    final fourth = c.read(contentAccessForReferenceProvider(request))!;
    expect(fourth.key, isNot(third.key));
  });

  test(
    'scoped profile overrides cannot reuse another credential context key',
    () {
      final parent = ProviderContainer(
        overrides: [
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: [profile('a')]),
          ),
          contentEffectivePolicyProvider.overrideWith(
            (ref, id) => const AsyncData('visibility'),
          ),
        ],
      );
      final child = ProviderContainer(
        parent: parent,
        overrides: [
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(
              initialConfigs: [profile('a', apiKey: 'child-fixture')],
            ),
          ),
        ],
      );
      addTearDown(parent.dispose);
      addTearDown(child.dispose);
      final request = ContentAccessRequest(reference: group);
      final rootAccess = parent.read(
        contentAccessForReferenceProvider(request),
      )!;
      final scopedAccess = child.read(
        contentAccessForReferenceProvider(request),
      )!;
      expect(rootAccess.config!.auth.apiKey, 'fixture');
      expect(scopedAccess.config!.auth.apiKey, 'child-fixture');
      expect(scopedAccess.key, isNot(rootAccess.key));
      expect(child.read(contentAccessContextProvider(rootAccess.key)), isNull);
    },
  );

  test(
    'resolving one source does not load policies for unrelated profiles',
    () {
      final seen = <String>{};
      final c = ProviderContainer(
        overrides: [
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(
              initialConfigs: [profile('a'), profile('b')],
            ),
          ),
          contentEffectivePolicyProvider.overrideWith((ref, id) {
            seen.add(id);
            return const AsyncData('visibility');
          }),
        ],
      );
      addTearDown(c.dispose);
      expect(
        c.read(
          contentAccessForReferenceProvider(
            ContentAccessRequest(reference: group),
          ),
        ),
        isNull,
      );
      expect(seen, isEmpty);
      expect(
        c.read(
          contentAccessForReferenceProvider(
            ContentAccessRequest(reference: group, profileIdHint: pid('a')),
          ),
        ),
        isNotNull,
      );
      expect(seen, {pid('a')});
    },
  );

  test('unknown policy and profileless contexts grant no source access', () {
    final c = ProviderContainer(
      overrides: [
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: [profile('a')]),
        ),
        contentEffectivePolicyProvider.overrideWith(
          (ref, config) => const AsyncLoading(),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(
      c.read(
        contentAccessForReferenceProvider(
          ContentAccessRequest(reference: group),
        ),
      ),
      isNull,
    );
    final anonymous = ContentAccessKey(
      engine: group.engine,
      siteNamespace: group.siteNamespace,
      authEpoch: 0,
      policyEpoch: 0,
    );
    expect(c.read(contentAccessContextProvider(anonymous)), isNull);
    expect(
      () => GroupLoadKey(
        reference: group,
        access: ContentAccessKey(
          engine: group.engine,
          siteNamespace: 'foreign.test',
          profileId: pid('a'),
          authEpoch: 0,
          policyEpoch: 0,
        ),
      ),
      throwsFormatException,
    );
  });
}
