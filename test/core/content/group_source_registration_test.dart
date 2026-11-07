import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/capabilities.dart';
import 'package:boorusama/core/content/groups/group_envelope_cache.dart';
import 'package:boorusama/core/content/providers.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../search/following_topics/topic_test_utils.dart';

void main() {
  final group = _fixtureGroup;

  test('registry wires an optional Group capability created by components', () {
    final registry = BooruRegistry();
    final parser = DefaultBooruParser(
      config: BooruYamlConfigs.values.firstWhere(
        (v) => v.type == BooruType.danbooru,
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repository = _Repo(container.read(_refProvider));
    final capability = _capability((access) => _Source(access));
    registry.register(
      BooruType.danbooru,
      BooruComponents(
        parser: parser,
        createBuilder: _Builder.new,
        createRepository: (_) => repository,
        createGroupCapability: (_) => capability,
      ),
    );
    final engine = registry.createEngine(
      parser.parse(),
      container.read(_refProvider),
    );
    final engines = BooruEngineRegistry()..register(BooruType.danbooru, engine);
    expect(engines.getGroupCapability(BooruType.danbooru), same(capability));
  });

  test(
    'source sharing, access identity, order keys, and Post hydration',
    () async {
      final config = _profile();
      late _Source source;
      var factories = 0;
      var postDetailCalls = 0;
      final container = ProviderContainer(
        overrides: [
          booruEngineRegistryProvider.overrideWith(
            (ref) => _registry(
              ref,
              () => _capability((access) {
                factories++;
                return source = _Source(
                  access.withEndpoint(Uri.parse('https://api.example.test')),
                );
              }),
              onPostAccess: () => postDetailCalls++,
            ),
          ),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: [config]),
          ),
          contentEffectivePolicyProvider.overrideWith(
            (ref, id) => const AsyncData('visible'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final access = container.read(
        contentAccessForReferenceProvider(
          ContentAccessRequest(reference: group),
        ),
      )!;
      expect(access.key.profileId, config.id);
      final metadata = GroupMetadataKey(reference: group, access: access.key);
      final newest = GroupLoadKey(
        reference: group,
        access: access.key,
        orderKey: 'newest',
      );
      final oldest = GroupLoadKey(
        reference: group,
        access: access.key,
        orderKey: 'oldest',
      );
      final subscriptions = [
        container.listen(groupSummaryProvider(metadata), (_, _) {}),
        container.listen(groupDetailsProvider(metadata), (_, _) {}),
        container.listen(groupMembersProvider(newest), (_, _) {}),
        container.listen(groupMembersProvider(oldest), (_, _) {}),
      ];
      addTearDown(() {
        for (final s in subscriptions) {
          s.close();
        }
      });

      final summaryFuture = container.read(
        groupSummaryProvider(metadata).future,
      );
      final detailsFuture = container.read(
        groupDetailsProvider(metadata).future,
      );
      final newestFuture = container.read(groupMembersProvider(newest).future);
      final oldestFuture = container.read(groupMembersProvider(oldest).future);
      await source.rawRequested.future;
      expect(source.rawCalls, 1);
      expect(source.access.baseUrl.host, 'api.example.test');
      expect(source.access.key.siteNamespace, 'example.test');
      source.completeEnvelope();
      final summary = await summaryFuture;
      final details = await detailsFuture;
      final newestState = await newestFuture;
      final oldestState = await oldestFuture;
      expect(summary.title, 'Fixture pool');
      expect(details.summary.reference, group);
      expect(source.summaryCalls, 1);
      expect(source.detailsCalls, 1);
      expect(source.memberCalls, 2);
      expect(source.orders.toSet(), {'newest', 'oldest'});
      expect(metadata, newest.metadata);
      expect(newest.metadata, oldest.metadata);
      expect(newest, isNot(oldest));
      expect(factories, 1);
      expect(
        newestState.members.map((m) => m.sourcePosition),
        List.generate(10, (i) => i),
      );
      expect(
        oldestState.members.map((m) => m.reference.sourceKey),
        List.generate(10, (i) => 'id:${10 - i}'),
      );
      expect(newestState.resolved.values, hasLength(10));
      for (var i = 0; i < 10; i++) {
        final entry =
            newestState.resolved.values.elementAt(i) as PostContentEntry;
        expect(identical(entry.post, source.posts[i]), isTrue);
      }
      expect(postDetailCalls, 0);
    },
  );

  test(
    'source factories cannot substitute another credential configuration',
    () {
      late _Source rejected;
      final container = ProviderContainer(
        overrides: [
          booruEngineRegistryProvider.overrideWith(
            (ref) => _registry(
              ref,
              () => _capability((access) {
                final other = BooruConfig.fromJson({
                  ...access.config!.toJson(),
                  'apiKey': 'other-fixture',
                });
                return rejected = _Source(
                  ContentAccessContext.profile(
                    config: other,
                    authEpoch: access.key.authEpoch,
                    policyEpoch: access.key.policyEpoch,
                  ),
                );
              }),
            ),
          ),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: [_profile()]),
          ),
          contentEffectivePolicyProvider.overrideWith(
            (ref, id) => const AsyncData('visibility'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final access = container.read(
        contentAccessForReferenceProvider(
          ContentAccessRequest(reference: group),
        ),
      )!;
      expect(
        () => container.read(contentGroupSourceProvider(access.key)),
        throwsA(isA<BooruError>()),
      );
      expect(rejected.disposed, isTrue);
      expect(rejected.rawCalls, 0);
    },
  );

  test('unsupported engine fails before policy preparation', () {
    var policyReads = 0;
    final unsupported = const ContentReferenceCodec().parse(
      engine: BooruType.szurubooru,
      site: Uri.parse('https://unsupported.test'),
      kind: ContentKind.group,
      sourceKey: 'pool:42',
    );
    final key = ContentAccessKey(
      engine: unsupported.engine,
      siteNamespace: unsupported.siteNamespace,
      profileId: '00000000-0000-4000-8000-000000000001',
      authEpoch: 1,
      policyEpoch: 1,
    );
    final container = ProviderContainer(
      overrides: [
        booruEngineRegistryProvider.overrideWithValue(BooruEngineRegistry()),
        contentEffectivePolicyProvider.overrideWith((ref, id) {
          policyReads++;
          return const AsyncData('visible');
        }),
      ],
    );
    addTearDown(container.dispose);
    expect(
      () => container.read(contentGroupSourceProvider(key)),
      throwsA(isA<BooruError>()),
    );
    expect(policyReads, 0);
  });
}

final _refProvider = Provider<Ref>((ref) => ref);

final _fixtureGroup = const ContentReferenceCodec().parse(
  engine: BooruType.danbooru,
  site: Uri.parse('https://example.test'),
  kind: ContentKind.group,
  sourceKey: 'pool:42',
);

class _Repo extends BooruRepository {
  _Repo(this.ref, {this.onPostAccess});
  final void Function()? onPostAccess;
  @override
  PostRepository<Post> post(BooruConfigSearch config) {
    onPostAccess?.call();
    throw StateError('Group hydration must reuse parsed Posts');
  }

  @override
  final Ref ref;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Builder extends BooruBuilder {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BooruEngineRegistry _registry(
  Ref ref,
  BooruGroupCapability Function() capability, {
  void Function()? onPostAccess,
}) {
  final config = BooruYamlConfigs.values.firstWhere(
    (v) => v.type == BooruType.danbooru,
  );
  final parser = DefaultBooruParser(config: config);
  final components = BooruComponents(
    parser: parser,
    createBuilder: _Builder.new,
    createRepository: (ref) => _Repo(ref, onPostAccess: onPostAccess),
    createGroupCapability: (_) => capability(),
  );
  final registry = BooruRegistry()..register(BooruType.danbooru, components);
  final engine = registry.createEngine(parser.parse(), ref);
  return BooruEngineRegistry()..register(BooruType.danbooru, engine);
}

BooruGroupCapability _capability(
  ContentGroupSource Function(ContentAccessContext) create,
) => BooruGroupCapability(
  engine: BooruType.danbooru,
  keyCodec: const BooruContentKeyCodec(BooruType.danbooru),
  createSource: create,
  presentation: _Presentation(),
);

BooruConfig _profile() => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': '00000000-0000-4000-8000-000000000001',
  'booruId': 1,
  'booruIdHint': 1,
  'url': 'https://example.test',
  'login': 'fixture',
  'apiKey': 'fixture-secret',
});

class _Presentation implements BooruGroupPresentation {
  @override
  bool supports(ContentGroupSummary summary) => true;
  @override
  GroupLayout layoutFor(ContentGroupSummary summary) => GroupLayout.memberGrid;
  @override
  String memberLabel(BuildContext context, ContentGroupSummary summary) =>
      'members';
  @override
  Widget buildCard(BuildContext context, ContentGroupSummary summary) =>
      const SizedBox.shrink();
  @override
  Widget buildDetails(BuildContext context, ContentGroupDetails details) =>
      const SizedBox.shrink();
}

class _Source extends ContentGroupSource {
  _Source(this.access)
    : cache = GroupEnvelopeCache<_Envelope>(access: access.key) {
    posts = List.generate(10, (i) {
      final original = testSearchPost(i + 1, null);
      return original.copyWith(
        origin: PostOrigin.fromSource(
          booruType: BooruType.danbooru,
          booruId: 1,
          source: access.config!.url,
          profileIdHint: access.key.profileId,
        ),
      );
    });
  }
  @override
  final ContentAccessContext access;
  final GroupEnvelopeCache<_Envelope> cache;
  late final List<Post> posts;
  final rawRequested = Completer<void>();
  final _raw = Completer<_Envelope>();
  var rawCalls = 0;
  var summaryCalls = 0;
  var detailsCalls = 0;
  var memberCalls = 0;
  final orders = <String?>[];
  var disposed = false;
  Future<_Envelope> _load() {
    rawCalls++;
    if (!rawRequested.isCompleted) rawRequested.complete();
    return _raw.future;
  }

  void completeEnvelope() => _raw.complete(_Envelope(posts));
  @override
  TaskEither<BooruError, ContentGroupSummary> loadSummary(
    ContentReference reference,
  ) => TaskEither(() async {
    summaryCalls++;
    final envelope = await cache.load(reference, _load);
    return right(envelope.summary);
  });
  @override
  TaskEither<BooruError, ContentGroupDetails> loadDetails(
    ContentReference reference,
  ) => TaskEither(() async {
    detailsCalls++;
    final envelope = await cache.load(reference, _load);
    return right(envelope.details);
  });
  @override
  TaskEither<BooruError, GroupMemberBatch> loadMembers(
    GroupMemberQuery query,
  ) => TaskEither(() async {
    memberCalls++;
    orders.add(query.orderKey);
    final envelope = await cache.load(query.reference, _load);
    final ordered = query.orderKey == 'oldest'
        ? envelope.posts.reversed.toList()
        : envelope.posts;
    final members = <GroupMember>[];
    final resolved = <ContentEntry>[];
    for (var i = 0; i < ordered.length; i++) {
      final post = ordered[i];
      final ref = const ContentReferenceCodec().parse(
        engine: access.key.engine,
        site: _fixtureGroup.site,
        kind: ContentKind.post,
        sourceKey: 'id:${post.id}',
      );
      members.add(
        GroupMember(
          reference: ref,
          memberKey: 'slot-${post.id - 1}',
          sourcePosition: post.id - 1,
        ),
      );
      resolved.add(PostContentEntry(reference: ref, post: post));
    }
    return right((page: ContentPage(items: members), resolved: resolved));
  });
  @override
  void invalidate(ContentReference reference) => cache.invalidate(reference);
  @override
  void dispose() {
    disposed = true;
    cache.dispose();
  }
}

class _Envelope {
  _Envelope(this.posts)
    : summary = ContentGroupSummary(
        reference: _fixtureGroup,
        title: 'Fixture pool',
      ),
      details = ContentGroupDetails(
        summary: ContentGroupSummary(
          reference: _fixtureGroup,
          title: 'Fixture pool',
        ),
      );
  final List<Post> posts;
  final ContentGroupSummary summary;
  final ContentGroupDetails details;
}
