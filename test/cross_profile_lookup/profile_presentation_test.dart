import 'package:boorusama/core/config_widgets/website_logo.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import 'page_test.dart' show pumpLookup;
import 'pixiv_share_lookup_test.dart' show artworkUrl, pumpPixivLookup;
import 'providers_test.dart' show Profiles, post, targetProfile;

void main() {
  for (final sharedArtwork in [false, true]) {
    testWidgets(
      '${sharedArtwork ? 'Pixiv' : 'post'} lookup shows profile icons without URLs or counts and Find More preserves paging',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final profile = BooruConfig.fromJson({
          ...targetProfile.toJson(),
          'name': 'A profile with a long descriptive name',
          if (sharedArtwork)
            'profileIcon': {'url': 'https://icons.test/custom-profile.png'},
        });
        final pages = <int>[];
        Future<PostResult<Post>> fetch(BooruConfig target, int page) async {
          pages.add(page);
          return PostResult(
            total: 999,
            hasMore: page == 1,
            posts: [
              post(target, sourceUrl: artworkUrl),
              if (page == 2) post(target, id: 43, sourceUrl: artworkUrl),
            ],
          );
        }

        await (sharedArtwork
            ? pumpPixivLookup(
                tester,
                profiles: Profiles([profile]),
                textScale: 2,
                fetch: fetch,
              )
            : pumpLookup(
                tester,
                profiles: Profiles([profile]),
                textScale: 2,
                fetch: fetch,
              ));
        await tester.pumpAndSettle();
        final header = find.byKey(ValueKey('profile-${profile.id}'));
        final icon = tester.widget<ConfigAwareWebsiteLogo>(
          find.descendant(
            of: header,
            matching: find.byType(ConfigAwareWebsiteLogo),
          ),
        );
        expect(icon.url, profile.url);
        expect(icon.customIconUrl, profile.profileIcon?.url);
        expect(find.text(profile.name), findsOneWidget);
        expect(find.textContaining('target.test'), findsNothing);
        expect(find.textContaining('source.test'), findsNothing);
        expect(find.textContaining('Results:'), findsNothing);
        expect(find.textContaining('Results loaded:'), findsNothing);
        expect(find.text('Load More'), findsNothing);
        await tester.ensureVisible(find.text('Find More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Find More'));
        await tester.pumpAndSettle();
        expect(pages, [1, 2]);
        expect(find.byKey(ValueKey('match-${profile.id}-42')), findsOneWidget);
        expect(find.byKey(ValueKey('match-${profile.id}-43')), findsOneWidget);
        expect(find.text('Find More'), findsNothing);
        expect(find.textContaining('Results:'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
