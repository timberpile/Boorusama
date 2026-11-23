import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/manage/src/widgets/current_booru_config_scope.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/navigation/page_presentation_profile.dart';
import 'package:boorusama/core/navigation/page_source_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _site = 'https://safebooru.donmai.us';
const _aId = '11111111-1111-4111-8111-111111111111';
const _bId = '22222222-2222-4222-8222-222222222222';
final _profileA = _profile(_aId);
final _profileB = _profile(_bId);
final _contextState = StateProvider<ContentAccessContext?>((ref) => null);

BooruConfig _profile(String id) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'booruId': BooruType.danbooru.id,
  'booruIdHint': BooruType.danbooru.id,
  'url': _site,
  'login': 'same-login',
  'apiKey': 'same-key',
});

ContentAccessContext _profileContext(BooruConfig config) =>
    ContentAccessContext.profile(config: config, authEpoch: 1, policyEpoch: 2);

void main() {
  testWidgets(
    'nested scopes inherit the key and revoked access cannot fall back',
    (
      tester,
    ) async {
      final context = _profileContext(_profileA);
      final key = context.key;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booruConfigProvider.overrideWith(
              () => BooruConfigNotifier(initialConfigs: [_profileA, _profileB]),
            ),
            contentAccessContextProvider(key).overrideWith(
              (ref) => ref.watch(_contextState),
            ),
            _contextState.overrideWith((ref) => context),
          ],
          child: MaterialApp(
            home: CurrentBooruConfigScope(
              config: _profileA,
              accessKey: key,
              requireAccess: true,
              child: CurrentBooruConfigScope(
                config: _profileA,
                child: const _AccessProbe(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('$_aId|$_aId|true|true'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('revoke'));
      await tester.pump();

      expect(
        find.text('${BooruConfig.empty.id}|none|true|false'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a same-auth profile cannot substitute for the keyed profile', (
    tester,
  ) async {
    final context = _profileContext(_profileA);
    expect(_profileA.auth, _profileB.auth);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: [_profileA, _profileB]),
          ),
          contentAccessContextProvider(context.key).overrideWithValue(context),
        ],
        child: MaterialApp(
          home: CurrentBooruConfigScope(
            config: _profileA,
            accessKey: context.key,
            requireAccess: true,
            child: CurrentBooruConfigScope(
              config: _profileB,
              child: const _AccessProbe(),
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('${BooruConfig.empty.id}|none|true|false'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'public scope marker does not create a saved profile or page source',
    (
      tester,
    ) async {
      final source = const AnonymousSourcePolicy().resolve(
        BooruType.danbooru,
        Uri.parse(_site),
      )!;
      final key = ContentAccessKey(
        engine: source.engine,
        siteNamespace: source.site.host,
        authEpoch: 10,
        policyEpoch: 11,
      );
      final scope = AnonymousReadScope(
        source: source,
        key: key,
        current: () => true,
        createDio: () =>
            throw StateError('The test must not create HTTP clients'),
      );
      addTearDown(scope.dispose);
      final publicConfig = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': '00000000-0000-4000-8000-000000000000',
        'booruId': source.engine.id,
        'booruIdHint': source.engine.id,
        'url': source.site.toString(),
        'login': null,
        'apiKey': null,
        'passHash': null,
        'proxySettings': null,
        'networkSettings': null,
      }).copyWith(anonymousReadScope: scope);
      final context = ContentAccessContext.anonymous(
        config: publicConfig,
        scope: scope,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentAccessContextProvider(key).overrideWithValue(context),
          ],
          child: MaterialApp(
            home: CurrentBooruConfigScope(
              config: publicConfig,
              accessKey: key,
              requireAccess: true,
              child: const _PublicAccessProbe(),
            ),
          ),
        ),
      );

      expect(find.text('public|true|true|true'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _AccessProbe extends ConsumerWidget {
  const _AccessProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(currentReadOnlyBooruConfigProvider);
    final key = ref.watch(currentContentAccessKeyProvider);
    final required = ref.watch(contentAccessRequiredProvider);
    final access = watchContentMediaAccess(ref, _profileA.auth);
    return Material(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${config.id}|${key?.profileId ?? 'none'}|$required|${access.allowed}',
          ),
          TextButton(
            onPressed: () => ref.read(_contextState.notifier).state = null,
            child: const Text('revoke'),
          ),
        ],
      ),
    );
  }
}

class _PublicAccessProbe extends ConsumerWidget {
  const _PublicAccessProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(currentReadOnlyBooruConfigProvider);
    final key = ref.watch(currentContentAccessKeyProvider);
    final required = ref.watch(contentAccessRequiredProvider);
    final profile = ref.watch(pagePresentationProfileProvider);
    final pageSource = ref.watch(explicitPageSourceProvider);
    final access = watchContentMediaAccess(ref, config.auth);
    return Material(
      child: Text(
        '${key?.profileId == null && key != null ? 'public' : 'private'}|$required|'
        '${profile == null}|${pageSource == null && access.allowed}',
      ),
    );
  }
}
