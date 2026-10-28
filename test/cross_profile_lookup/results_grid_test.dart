import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import 'page_test.dart' show pumpLookup;
import 'pixiv_share_lookup_test.dart' show artworkUrl, pumpPixivLookup;
import 'providers_test.dart' show Profiles, post, sourceProfile, targetProfile;

void main() {
  for (final sharedArtwork in [false, true]) {
    testWidgets(
      '${sharedArtwork ? 'shared artwork' : 'other profiles'} has three thumbnail columns and opens the tapped target post at narrow width and enlarged text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final profiles = Profiles([sourceProfile, targetProfile]);
        Future<PostResult<Post>> fetch(BooruConfig profile, int page) async =>
            PostResult(
              total: null,
              hasMore: false,
              posts: [
                for (var id = 42; id <= 45; id++)
                  post(profile, id: id, sourceUrl: artworkUrl),
              ],
            );
        final router = await (sharedArtwork
            ? pumpPixivLookup(
                tester,
                profiles: profiles,
                textScale: 2,
                fetch: fetch,
              )
            : pumpLookup(
                tester,
                profiles: profiles,
                textScale: 2,
                fetch: fetch,
              ));
        await tester.pumpAndSettle();
        Finder tile(int id) =>
            find.byKey(ValueKey('match-${targetProfile.id}-$id'));
        final cells = [
          for (var id = 42; id <= 45; id++) tester.getRect(tile(id)),
        ];
        expect(cells[0].top, closeTo(cells[1].top, 0.01));
        expect(cells[1].top, closeTo(cells[2].top, 0.01));
        expect(cells[0].right, lessThan(cells[1].left));
        expect(cells[1].right, lessThan(cells[2].left));
        expect(cells[3].left, closeTo(cells[0].left, 0.01));
        expect(cells[3].top, greaterThan(cells[0].bottom));
        expect(cells[0].width, closeTo(cells[0].height, 0.01));
        for (var id = 42; id <= 45; id++) {
          final image = tester.widget<BooruImage>(
            find.descendant(of: tile(id), matching: find.byType(BooruImage)),
          );
          expect(image.config, targetProfile.auth);
          expect(image.imageUrl, post(targetProfile, id: id).thumbnailImageUrl);
        }
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(tile(45));
        await tester.pumpAndSettle();
        await tester.tap(tile(45));
        await tester.pumpAndSettle();
        expect(find.text('Opened 45 with Target'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        expect(tile(45), findsOneWidget);
        expect(profiles.state, [sourceProfile, targetProfile]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
