import 'dart:async';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/boorus/pixiv/works/work_source.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'work_test_fixtures.dart';

Future<T> read<T>(TaskEither<BooruError, T> result) async =>
    (await result.run()).fold((error) => throw error, (value) => value);

void main() {
  test(
    'a list envelope without its Page manifest resolves details only on open',
    () async {
      final access = workAccess();
      var requests = 0;
      final source = PixivWorkSource(
        access: access,
        fetchWork: (_) async {
          requests++;
          return work();
        },
      );
      addTearDown(source.dispose);
      source.seedWork(work(pages: const []));
      expect(requests, 0);
      final batch = await read(
        source.loadMembers(
          GroupMemberQuery(
            reference: pixivWorkReference(access, 120),
          ),
        ),
      );
      expect(requests, 1);
      expect(batch.page.items.map((member) => member.sourcePosition), [
        0,
        1,
        2,
      ]);
      expect(batch.resolved, hasLength(3));
    },
  );

  test(
    'captured Work policy rejects list seeds and direct reads consistently',
    () async {
      final access = workAccess();
      final source = PixivWorkSource(
        access: access,
        blacklist: {'fixture'},
        fetchWork: (_) async => work(),
      );
      addTearDown(source.dispose);
      expect(() => source.seedWork(work()), throwsStateError);
      expect(
        (await source.loadDetails(pixivWorkReference(access, 120)).run())
            .isLeft(),
        isTrue,
      );
    },
  );

  test(
    'contradictory source count fails without silently dropping source pages',
    () async {
      final access = workAccess();
      final source = PixivWorkSource(
        access: access,
        fetchWork: (_) async => work(
          pageCount: 2,
          pages: [page(120, 0), page(120, 1), page(120, 2)],
        ),
      );
      addTearDown(source.dispose);
      expect(
        (await source
                .loadMembers(
                  GroupMemberQuery(reference: pixivWorkReference(access, 120)),
                )
                .run())
            .isLeft(),
        isTrue,
      );
    },
  );

  test(
    'restricted media retains its slot without exposing an actionable Post',
    () async {
      final access = workAccess();
      final source = PixivWorkSource(
        access: access,
        fetchWork: (_) async => work(
          pages: [
            page(120, 0),
            page(
              120,
              1,
              original:
                  'https://s.pximg.net/common/images/limit_unviewable_360.png',
            ),
            page(120, 2),
          ],
        ),
      );
      addTearDown(source.dispose);
      final batch = await read(
        source.loadMembers(
          GroupMemberQuery(reference: pixivWorkReference(access, 120)),
        ),
      );
      expect(batch.page.items[1].availability, MemberAvailability.unavailable);
      expect(batch.page.items[1].sourcePosition, 1);
      expect(
        batch.resolved.whereType<PostContentEntry>().map(
          (entry) => entry.post.pageIndex,
        ),
        [0, 2],
      );
    },
  );

  test(
    'Summary, Details and Page consumers share one captured artwork request',
    () async {
      final access = workAccess();
      final gate = Completer<PixivIllustDto?>();
      var calls = 0;
      final source = PixivWorkSource(
        access: access,
        fetchWork: (id) {
          expect(id, 120);
          calls++;
          return gate.future;
        },
      );
      addTearDown(source.dispose);
      final reference = pixivWorkReference(access, 120);
      final summary = read(source.loadSummary(reference));
      final details = read(source.loadDetails(reference));
      final members = read(
        source.loadMembers(GroupMemberQuery(reference: reference)),
      );
      gate.complete(work(pages: [page(120, 0), null, page(120, 2)]));
      expect((await summary).title, 'Work 120');
      expect((await details).creators!.single.displayName, 'Artist');
      final batch = await members;
      expect(calls, 1);
      expect(batch.page.items.map((member) => member.sourcePosition), [
        0,
        1,
        2,
      ]);
      expect(batch.page.items.map((member) => member.availability), [
        MemberAvailability.available,
        MemberAvailability.unavailable,
        MemberAvailability.available,
      ]);
      expect(
        batch.resolved.whereType<PostContentEntry>().map(
          (entry) => entry.post.pageIndex,
        ),
        [0, 2],
      );
      expect(
        batch.resolved.every(
          (entry) =>
              (entry as PostContentEntry).post.origin.profileIdHint ==
              access.key.profileId,
        ),
        isTrue,
      );
    },
  );

  test('native envelope seed avoids a detail request and refresh cannot reseed stale data', () async {
    final access = workAccess();
    var calls = 0;
    final source = PixivWorkSource(
      access: access,
      fetchWork: (_) async {
        calls++;
        return work(pages: [page(120, 0), page(120, 1), page(120, 2)]);
      },
    );
    addTearDown(source.dispose);
    final original = work(pages: [page(120, 0), null, page(120, 2)]);
    source.seedWork(original);
    final reference = pixivWorkReference(access, 120);
    final before = await read(
      source.loadMembers(GroupMemberQuery(reference: reference)),
    );
    expect(calls, 0);
    source.invalidate(reference);
    source.seedWork(original);
    final after = await read(
      source.loadMembers(GroupMemberQuery(reference: reference)),
    );
    expect(calls, 1);
    expect(after.page.items[1].availability, MemberAvailability.available);
    expect(after.page.items[2].memberKey, before.page.items[2].memberKey);
  });

  test('bounded member windows retain source slots and reject foreign/stale cursors', () async {
    final access = workAccess();
    final source = PixivWorkSource(
      access: access,
      fetchWork: (_) async => work(),
    );
    addTearDown(source.dispose);
    final reference = pixivWorkReference(access, 120);
    final first = await read(
      source.loadMembers(
        GroupMemberQuery(reference: reference, requestedLimit: 2),
      ),
    );
    expect(first.page.items.map((member) => member.sourcePosition), [0, 1]);
    final last = await read(
      source.loadMembers(
        GroupMemberQuery(
          reference: reference,
          requestedLimit: 2,
          cursor: first.page.next,
        ),
      ),
    );
    expect(last.page.items.single.sourcePosition, 2);
    expect(last.page.next, isNull);
    expect(last.page.total, 3);
    final foreign = pixivWorkReference(access, 121);
    expect(
      await source
          .loadMembers(
            GroupMemberQuery(
              reference: foreign,
              requestedLimit: 2,
              cursor: first.page.next,
            ),
          )
          .run(),
      isA<Left<BooruError, GroupMemberBatch>>(),
    );
    source.invalidate(reference);
    expect(
      await source
          .loadMembers(
            GroupMemberQuery(
              reference: reference,
              requestedLimit: 2,
              cursor: first.page.next,
            ),
          )
          .run(),
      isA<Left<BooruError, GroupMemberBatch>>(),
    );
  });

  test('account sources do not share envelopes or Page actor hints', () async {
    var calls = 0;
    Future<PixivIllustDto?> load(int _) async {
      calls++;
      return work();
    }

    final a = workAccess();
    final b = workAccess(id: '22222222-2222-4222-8222-222222222222');
    final one = PixivWorkSource(access: a, fetchWork: load);
    final two = PixivWorkSource(access: b, fetchWork: load);
    addTearDown(one.dispose);
    addTearDown(two.dispose);
    final first = await read(
      one.loadMembers(GroupMemberQuery(reference: pixivWorkReference(a, 120))),
    );
    final second = await read(
      two.loadMembers(GroupMemberQuery(reference: pixivWorkReference(b, 120))),
    );
    expect(calls, 2);
    expect(
      (first.resolved.first as PostContentEntry).post.origin.profileIdHint,
      a.key.profileId,
    );
    expect(
      (second.resolved.first as PostContentEntry).post.origin.profileIdHint,
      b.key.profileId,
    );
  });

  test(
    'foreign source fails before dispatch and disposed requests cannot publish',
    () async {
      final access = workAccess();
      final gate = Completer<PixivIllustDto?>();
      var calls = 0;
      final source = PixivWorkSource(
        access: access,
        fetchWork: (_) {
          calls++;
          return gate.future;
        },
      );
      final foreign = const ContentReferenceCodec().parse(
        engine: BooruType.pixiv,
        site: Uri.parse('https://foreign.example'),
        kind: ContentKind.group,
        sourceKey: 'work:120',
      );
      expect(
        await source.loadDetails(foreign).run(),
        isA<Left<BooruError, ContentGroupDetails>>(),
      );
      expect(calls, 0);
      final pending = source.loadDetails(pixivWorkReference(access, 120)).run();
      source.dispose();
      gate.complete(work());
      expect(await pending, isA<Left<BooruError, ContentGroupDetails>>());
    },
  );
}
