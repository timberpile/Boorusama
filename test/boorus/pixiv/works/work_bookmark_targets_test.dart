import 'dart:convert';

import 'package:boorusama/boorus/pixiv/posts/post_codec.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_targets.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/bookmarks/src/data/stored_bookmark_codec.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'work_test_fixtures.dart';

void main() {
  test(
    'Work and Page drafts are separate targets with no implicit member payload',
    () {
      final access = workAccess();
      final dto = work();
      final summary = pixivWorkSummary(dto, access);
      final details = pixivWorkDetails(dto, access);
      final page = pixivWorkPagePosts(dto, access).last;
      final workTarget = PixivWorkBookmarkTarget(
        access: access,
        summary: summary,
        details: details,
      );
      final pageTarget = PixivPageBookmarkTarget(access: access, post: page);
      final at = DateTime.utc(2026, 1, 2);
      final groupDraft = workTarget.draft(currentAccess: access, at: at);
      final pageDraft = pageTarget.draft(currentAccess: access, at: at);
      expect(workTarget.identity.kind, ContentKind.group);
      expect(workTarget.identity.sourceKey, 'work:120');
      expect(pageTarget.identity.kind, ContentKind.post);
      expect(pageTarget.identity.sourceKey, 'work-page:120:2');
      expect(groupDraft.snapshot.details, details);
      expect(groupDraft.summary.memberCount, 3);
      expect(groupDraft.snapshot.index!.basis, GroupTagIndexBasis.sourceGroup);
      expect(pageDraft.post.pageIndex, 2);
      expect(pageDraft.post.illustId, 120);
      expect(pageDraft.post.detailFacts.description, isNull);
      const codec = StoredBookmarkCodec(postDataCodec: _postCodec);
      final groupWire = codec.encodeForTransfer(groupDraft);
      final pageWire = codec.encodeForTransfer(pageDraft);
      expect(groupWire['kind'], 'group');
      expect(pageWire['kind'], 'post');
      expect(jsonEncode(groupWire), isNot(contains('work-page:120:1')));
      expect(jsonEncode(groupWire), isNot(contains('original/120_p2')));
      expect(codec.decode(groupWire), isA<ContentGroupBookmark>());
      final restoredPage = codec.decode(pageWire) as PostBookmark;
      expect(restoredPage.post.pageIndex, 2);
      expect(
        restoredPage.post.pixivData!.stableBookmarkPostKey,
        'work-page:120:2',
      );
    },
  );

  test('Summary-only target is synchronous and retains unknown Details', () {
    final access = workAccess();
    final target = PixivWorkBookmarkTarget(
      access: access,
      summary: pixivWorkSummary(work(), access),
    );
    final draft = target.draft(currentAccess: access, at: DateTime.utc(2026));
    expect(draft.snapshot.details, isNull);
    expect(draft.sourceProfileHint, access.key.profileId);
    expect(draft.id, 0, reason: 'Draft IDs are not local-record selectors');
  });

  test('single-page Work and its Page remain distinct and captures survive later swipes', () {
    final access = workAccess();
    final dto = work(pageCount: 1, type: 'illust');
    final workTarget = PixivWorkBookmarkTarget(
      access: access,
      summary: pixivWorkSummary(dto, access),
    );
    final captured = PixivPageBookmarkTarget(
      access: access,
      post: pixivWorkPagePosts(dto, access).single,
    );
    final later = PixivPageBookmarkTarget(
      access: access,
      post: pixivWorkPagePosts(work(id: 121), access).last,
    );
    expect(captured.identity.sourceKey, 'work-page:120:0');
    expect(later.identity.sourceKey, 'work-page:121:2');
    expect(
      captured
          .draft(currentAccess: access, at: DateTime.utc(2026))
          .post
          .illustId,
      120,
    );
    expect(captured.identity, isNot(workTarget.identity));
  });

  test(
    'captured targets reject revoked or substituted actors and foreign Pages',
    () {
      final access = workAccess();
      final other = workAccess(id: '22222222-2222-4222-8222-222222222222');
      final target = PixivWorkBookmarkTarget(
        access: access,
        summary: pixivWorkSummary(work(), access),
      );
      final page = PixivPageBookmarkTarget(
        access: access,
        post: pixivWorkPagePosts(work(), access).last,
      );
      for (final current in [null, other]) {
        expect(
          () => target.draft(currentAccess: current, at: DateTime.utc(2026)),
          throwsStateError,
        );
        expect(
          () => page.draft(currentAccess: current, at: DateTime.utc(2026)),
          throwsStateError,
        );
      }
      expect(
        () => PixivPageBookmarkTarget(access: other, post: page.post),
        throwsFormatException,
      );
      expect(
        () => PixivWorkBookmarkTarget(
          access: access,
          summary: pixivWorkSummary(
            work(),
            workAccess(site: 'https://foreign.example'),
          ),
        ),
        throwsFormatException,
      );
    },
  );
}

PixivPostCodec _postCodec(BooruType _) => const PixivPostCodec();
