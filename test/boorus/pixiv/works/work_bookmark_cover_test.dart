import 'package:boorusama/boorus/pixiv/works/bookmark_targets.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_native_group_card.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../../../core/search/following_topics/following_topic_test_utils.dart';
import 'work_test_fixtures.dart';

void main() {
  for (final scenario in ['allowed', 'deleted', 'banned', 'missing profile']) {
    for (final quality in [ImageQuality.low, ImageQuality.original]) {
      testWidgets(
        'saved Work cover $scenario at $quality uses only policy-approved stored media',
        (tester) async {
          final access = workAccess();
          final summary = pixivWorkSummary(work(), access);
          final cover = summary.cover!;
          final bookmark =
              PixivWorkBookmarkTarget(access: access, summary: summary)
                  .draft(currentAccess: access, at: DateTime.utc(2026))
                  .copyWith(
                    id: 7,
                    snapshot: StoredGroupSnapshot(
                      summary: ContentGroupSummary(
                        reference: summary.reference,
                        title: summary.title,
                        previewTags: summary.previewTags,
                        cover: GroupCover(
                          thumbnail: cover.thumbnail,
                          sample: cover.sample,
                          original: Uri.parse(
                            'https://i.pximg.net/never-original.jpg',
                          ),
                          visibility: GroupCoverVisibility(
                            tags: const ['fixture'],
                            rating: 'general',
                            deleted: scenario == 'deleted',
                            banned: scenario == 'banned',
                          ),
                        ),
                      ),
                    ),
                  );
          var sourceReads = 0;
          final harness = FollowingTopicHarness(
            profiles: scenario == 'missing profile' ? [] : [access.config!],
            settings: Settings.defaultSettings.copyWith(
              listing: Settings.defaultSettings.listing.copyWith(
                imageQuality: quality,
              ),
            ),
            overrides: [
              contentGroupSourceStateProvider.overrideWith((ref, key) {
                sourceReads++;
                throw StateError(
                  'A saved cover must not request metadata or members',
                );
              }),
            ],
          );
          addTearDown(harness.dispose);
          await harness.pump(
            tester,
            Scaffold(
              body: SizedBox.square(
                dimension: 180,
                child: BookmarkNativeGroupCover(bookmark: bookmark),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (scenario == 'allowed') {
            final image = tester.widget<BooruImage>(find.byType(BooruImage));
            expect(
              image.imageUrl,
              quality == ImageQuality.low
                  ? cover.thumbnail.toString()
                  : cover.sample.toString(),
            );
            expect(image.imageUrl, isNot(contains('never-original')));
          } else {
            expect(find.byType(BooruImage), findsNothing);
          }
          expect(sourceReads, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
