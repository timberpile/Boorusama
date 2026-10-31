import 'dart:async';
import 'dart:io';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/posts/links/boorusama_artist_link.dart';
import 'package:boorusama/core/posts/links/boorusama_link_file.dart';
import 'package:boorusama/core/posts/links/share_artist_link_button.dart';
import 'package:boorusama/core/posts/shares/src/share_action_adapter.dart';
import 'package:boorusama/boorus/danbooru/artists/artist/src/widgets/artist_identity.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/topic_follow_control.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../search/following_topics/following_topic_test_utils.dart';
import '../shares/share_test_utils.dart';

class _FileSystem extends IoFileSystem {
  const _FileSystem(this.root);
  final String root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  for (final size in [
    (width: 320.0, scale: 1.0),
    (width: 320.0, scale: 2.0),
    (width: 1280.0, scale: 2.0),
  ]) {
    final scale = size.scale;
    testWidgets(
      'actual artist header shares one retained document at width $size, scale $scale',
      (tester) async {
        tester.view.physicalSize = Size(size.width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('artist-share-'),
        ))!;
        addTearDown(() => root.delete(recursive: true));
        final banner = ArtistBannerSnapshot();
        addTearDown(banner.dispose);
        final received = Completer<ShareParams>();
        final response = Completer<ShareResult>();
        var calls = 0;
        final config = BooruConfig.fromJson({
          ...testProfile.toJson(),
          'booruId': BooruType.danbooru.id,
          'booruIdHint': BooruType.danbooru.id,
          'url': 'https://artist.test/',
          'name': 'My Artist Profile',
        });
        final harness = FollowingTopicHarness(
          profiles: [config],
          overrides: [
            appFileSystemProvider.overrideWithValue(_FileSystem(root.path)),
            artistLinkShareAdapterProvider.overrideWithValue(
              ShareActionAdapter((params) {
                calls++;
                received.complete(params);
                return response.future;
              }),
            ),
          ],
        );
        addTearDown(harness.dispose);
        await harness.pump(
          tester,
          MediaQuery(
            data: MediaQueryData(
              size: Size(size.width, 640),
              textScaler: TextScaler.linear(scale),
            ),
            child: CurrentBooruConfigScope(
              config: config,
              child: Scaffold(
                body: ArtistIdentity(artistName: 'artist_one', banner: banner),
              ),
            ),
          ),
        );
        final action = find.descendant(
          of: find.byType(ArtistLinkShareButton),
          matching: find.byType(IconButton),
        );
        expect(action.hitTestable(), findsOneWidget);
        final follow = find.byType(FollowTopicButton);
        expect(
          tester.getRect(action).left,
          greaterThanOrEqualTo(tester.getRect(follow).right),
        );
        expect(tester.getRect(action).top, lessThan(80));
        expect(find.byIcon(Icons.share), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(tester.getRect(action).right, lessThanOrEqualTo(size.width));
        expect(tester.widget<IconButton>(action).onPressed, isNotNull);
        await tester.tap(action);
        final params = (await tester.runAsync(() async {
          await pumpUntilShareCondition(
            tester,
            () => received.isCompleted,
            reason: 'The artist header must hand off its document',
          );
          return received.future;
        }))!;
        await tester.pump();
        expect(tester.widget<IconButton>(action).onPressed, isNull);
        expect(calls, 1);
        expect(params.files, hasLength(1));
        expect(params.uri, isNull);
        final file = params.files!.single;
        expect(file.name, 'My Artist Profile-artist_one.bslink');
        expect(file.mimeType, BoorusamaLinkFile.mimeType);
        final document = await tester.runAsync(
          () async => BoorusamaLinkFile.decode(await file.readAsBytes()),
        );
        expect(
          BoorusamaArtistLink.parse(document!.uri.toString()).artistName,
          'artist_one',
        );
        response.complete(const ShareResult('', ShareResultStatus.success));
        await tester.pumpAndSettle();
        expect(tester.widget<IconButton>(action).onPressed, isNotNull);
        expect(await tester.runAsync(() => File(file.path).exists()), isTrue);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
