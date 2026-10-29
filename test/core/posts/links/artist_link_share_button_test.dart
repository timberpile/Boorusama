import 'dart:async';
import 'dart:io';

import 'package:boorusama/boorus/danbooru/artists/artist/src/widgets/artist_posts_header.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/posts/links/boorusama_artist_link.dart';
import 'package:boorusama/core/posts/links/boorusama_link_file.dart';
import 'package:boorusama/core/posts/links/share_artist_link_button.dart';
import 'package:boorusama/core/posts/shares/src/share_action_adapter.dart';
import 'package:boorusama/core/tags/tag/types.dart';
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
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'actual artist header shares one retained document at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('artist-share-'),
        ))!;
        addTearDown(() => root.delete(recursive: true));
        final received = Completer<ShareParams>();
        final response = Completer<ShareResult>();
        var calls = 0;
        final config = BooruConfig.fromJson({
          ...testProfile.toJson(),
          'booruId': BooruType.danbooru.id,
          'booruIdHint': BooruType.danbooru.id,
          'url': 'https://artist.test/',
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
              size: const Size(320, 640),
              textScaler: TextScaler.linear(scale),
            ),
            child: CurrentBooruConfigScope(
              config: config,
              child: Scaffold(
                body: DanbooruArtistPostsHeader(
                  artistName: 'artist_one',
                  category: TagFilterCategory.newest,
                  onCategoryChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        final action = find.descendant(
          of: find.byType(ArtistLinkShareButton),
          matching: find.byType(IconButton),
        );
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.getRect(action).right, lessThanOrEqualTo(320));
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
        expect(file.name, 'boorusama-artist.bslink');
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
