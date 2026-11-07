import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../search/following_topics/topic_test_utils.dart';

void main() {
  const codec = ContentReferenceCodec();
  final site = Uri.parse('https://example.test/booru');
  ContentReference reference(
    String key, [
    ContentKind kind = ContentKind.post,
  ]) => codec.parse(
    engine: BooruType.danbooru,
    site: site,
    kind: kind,
    sourceKey: key,
  );
  Post post(int id) => testSearchPost(id, null).copyWith(
    origin: PostOrigin.fromSource(
      booruType: BooruType.danbooru,
      booruId: 1,
      source: site.toString(),
    ),
  );

  test(
    'repeated references preserve membership slots with one hydrated Post',
    () {
      final members = [
        GroupMember(
          reference: reference('id:7'),
          memberKey: 'slot:0',
          sourcePosition: 0,
        ),
        GroupMember(
          reference: reference('id:8'),
          memberKey: 'slot:1',
          sourcePosition: 1,
          availability: MemberAvailability.unavailable,
        ),
        GroupMember(
          reference: reference('id:7'),
          memberKey: 'slot:2',
          sourcePosition: 2,
        ),
      ];
      final realPost = post(7);
      final result = validateGroupMemberBatch(
        GroupMemberQuery(reference: reference('pool:42', ContentKind.group)),
        (
          page: ContentPage(items: members, total: 3),
          resolved: [
            PostContentEntry(reference: reference('id:7'), post: realPost),
          ],
        ),
      );
      members.clear();
      expect(result.page.items.map((m) => m.sourcePosition), [0, 1, 2]);
      expect(result.page.items.map((m) => m.memberKey), [
        'slot:0',
        'slot:1',
        'slot:2',
      ]);
      expect(result.resolved, hasLength(1));
      expect((result.resolved.single as PostContentEntry).post, same(realPost));
      expect(() => result.resolved.clear(), throwsUnsupportedError);
    },
  );

  test('nested and cyclic references remain inert, and filtering does not exhaust pages', () {
    final first = reference('pool:42', ContentKind.group);
    final second = reference('pool:43', ContentKind.group);
    final batch = validateGroupMemberBatch(GroupMemberQuery(reference: first), (
      page: ContentPage(
        items: [
          GroupMember(reference: second, memberKey: 'child'),
          GroupMember(reference: first, memberKey: 'cycle'),
        ],
        next: ContentCursor('next:2'),
      ),
      resolved: [
        GroupContentEntry(summary: ContentGroupSummary(reference: second)),
      ],
    ));
    expect(batch.page.items, hasLength(2));
    expect(batch.resolved, hasLength(1));
    final empty = ContentPage<GroupMember>(
      items: const [],
      next: ContentCursor('next:3'),
      total: 10,
    );
    expect(empty.items, isEmpty);
    expect(empty.next, isNotNull);
    expect(empty.total, 10);
  });

  test('unavailable placeholders cannot carry hydrated blocked metadata', () {
    final ref = reference('id:7');
    expect(
      () => validateGroupMemberBatch(
        GroupMemberQuery(reference: reference('pool:42', ContentKind.group)),
        (
          page: ContentPage(
            items: [
              GroupMember(
                reference: ref,
                memberKey: 'blocked',
                availability: MemberAvailability.unavailable,
              ),
            ],
          ),
          resolved: [PostContentEntry(reference: ref, post: post(7))],
        ),
      ),
      throwsFormatException,
    );
  });

  test(
    'invalid hydration and conflicting occurrence keys fail before publication',
    () {
      final group = reference('pool:42', ContentKind.group);
      final member = GroupMember(
        reference: reference('id:7'),
        memberKey: 'slot',
      );
      expect(
        () => PostContentEntry(reference: reference('id:8'), post: post(7)),
        throwsFormatException,
      );
      expect(
        () => PostContentEntry(reference: group, post: post(7)),
        throwsFormatException,
      );
      expect(
        () => validateGroupMemberBatch(GroupMemberQuery(reference: group), (
          page: ContentPage(
            items: [
              member,
              GroupMember(reference: reference('id:8'), memberKey: 'slot'),
            ],
          ),
          resolved: <ContentEntry>[],
        )),
        throwsFormatException,
      );
      expect(
        () => validateGroupMemberBatch(GroupMemberQuery(reference: group), (
          page: ContentPage(items: [member]),
          resolved: [
            PostContentEntry(reference: reference('id:8'), post: post(8)),
          ],
        )),
        throwsFormatException,
      );
      expect(
        () => GroupMember(
          reference: member.reference,
          memberKey: '',
          sourcePosition: 0,
        ),
        throwsFormatException,
      );
      expect(
        () => GroupMember(
          reference: member.reference,
          memberKey: 'slot',
          sourcePosition: -1,
        ),
        throwsFormatException,
      );
      expect(
        () => GroupMemberQuery(reference: member.reference),
        throwsFormatException,
      );
      expect(
        () => ContentPage<GroupMember>(items: const [], total: -1),
        throwsFormatException,
      );
      expect(() => ContentCursor(''), throwsFormatException);
    },
  );
}
