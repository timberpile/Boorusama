import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/groups/related_group_counts.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

GroupMetadataKey key({
  int id = 42,
  int auth = 1,
  int policy = 1,
  String site = 'https://example.test',
  String? kind,
}) => GroupMetadataKey(
  reference: const ContentReferenceCodec().parse(
    engine: BooruType.danbooru,
    site: Uri.parse(site),
    kind: ContentKind.group,
    sourceKey: '${kind ?? 'related'}:$id',
  ),
  access: ContentAccessKey(
    engine: BooruType.danbooru,
    siteNamespace: site,
    authEpoch: auth,
    policyEpoch: policy,
  ),
);

void main() {
  late ProviderContainer container;
  late RelatedGroupCounts counts;
  setUp(() {
    container = ProviderContainer();
    counts = container.read(relatedGroupCountsProvider.notifier);
  });
  tearDown(() => container.dispose());
  int? total(GroupMetadataKey key, {int? fallback}) => relatedGroupTotal(
    container.read(relatedGroupCountsProvider),
    key,
    fallback: fallback,
  );

  test(
    'normal reads publish authoritative totals to multiple passive observers',
    () {
      final observed = <int?>[];
      final subscription = container.listen(
        relatedGroupCountsProvider.select(
          (state) => relatedGroupTotal(state, key()),
        ),
        (_, next) => observed.add(next),
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final read = counts.begin(key());
      expect(observed, [null]);
      counts.publish(read, 42);
      expect(observed, [null, 42]);
      expect(total(key()), 42);
      counts.publish(counts.begin(key()), null);
      expect(total(key()), 42);
      counts.publish(counts.begin(key()), 0);
      expect(total(key()), 0);
    },
  );

  test(
    'canonical identity shares counts across locators, never actors or sites',
    () {
      counts.publish(counts.begin(key()), 17);
      expect(total(key(site: 'http://example.test')), 17);
      expect(total(key(auth: 2)), isNull);
      expect(total(key(policy: 2)), isNull);
      expect(total(key(site: 'https://other.test')), isNull);
      expect(total(key(id: 43)), isNull);
    },
  );

  test('valid saved totals are fallback only; refresh suppresses obsolete snapshots', () {
    expect(total(key(), fallback: 7), 7);
    expect(total(key(), fallback: -1), isNull);
    final old = counts.begin(key());
    counts.publish(old, 9);
    counts.invalidate(key());
    expect(total(key(), fallback: 7), isNull);
    counts.publish(old, 500);
    expect(total(key()), isNull);
    counts.publish(counts.begin(key()), 11);
    expect(total(key(), fallback: 7), 11);
  });

  test('older completed reads cannot replace a newer authoritative count', () {
    final earlier = counts.begin(key());
    final later = counts.begin(key());
    counts.publish(later, 12);
    counts.publish(earlier, 99);
    expect(total(key()), 12);
  });

  test(
    'unknown and invalid API totals never overwrite an authoritative count',
    () {
      counts.publish(counts.begin(key()), 8);
      counts.publish(counts.begin(key()), null);
      counts.publish(counts.begin(key()), -1);
      expect(total(key()), 8);
      expect(counts.begin(key(kind: 'pool')), isNull);
      expect(total(key(kind: 'pool')), isNull);
    },
  );

  test('bounded retention fences evicted reads and retains recent counts', () {
    final small = ProviderContainer(
      overrides: [
        relatedGroupCountsProvider.overrideWith(
          () => RelatedGroupCounts(maxEntries: 2),
        ),
      ],
    );
    addTearDown(small.dispose);
    final cache = small.read(relatedGroupCountsProvider.notifier);
    final evicted = cache.begin(key(id: 1));
    cache.publish(evicted, 1);
    cache.publish(cache.begin(key(id: 2)), 2);
    cache.publish(cache.begin(key(id: 3)), 3);
    cache.publish(evicted, 100);
    final state = small.read(relatedGroupCountsProvider);
    expect(state, hasLength(2));
    expect(relatedGroupTotal(state, key(id: 1)), isNull);
    expect(relatedGroupTotal(state, key(id: 2)), 2);
    expect(relatedGroupTotal(state, key(id: 3)), 3);
  });

  test('container lifetime ends retention and late publication safely', () {
    final first = ProviderContainer();
    final cache = first.read(relatedGroupCountsProvider.notifier);
    final read = cache.begin(key());
    cache.publish(read, 9);
    first.dispose();
    cache.publish(read, 12);
    expect(total(key()), isNull);
  });
}
