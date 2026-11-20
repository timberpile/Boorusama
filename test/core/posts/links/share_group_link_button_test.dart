import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/boorus/pixiv/works/work_timeline.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/groups/group_members_provider.dart';
import 'package:boorusama/core/config_widgets/website_logo.dart';
import 'package:boorusama/core/posts/details/src/providers/viewer_source_access_provider.dart';
import 'package:boorusama/core/posts/details/src/providers/media_group_provider.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/details/src/widgets/group_viewer_scope.dart';
import 'package:boorusama/core/posts/links/boorusama_group_link.dart';
import 'package:boorusama/core/posts/links/boorusama_link_file.dart';
import 'package:boorusama/core/posts/links/share_group_link_button.dart';
import 'package:boorusama/core/posts/shares/src/share_action_adapter.dart';
import 'package:boorusama/core/posts/shares/src/share_payload_tile.dart';
import 'package:boorusama/core/posts/shares/src/share_payloads.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../support/fakes/memory_app_file_system.dart';
import '../../search/following_topics/following_topic_test_utils.dart';

class _Profiles extends BooruConfigNotifier {
  _Profiles(this.profile) : super(initialConfigs: [profile]);
  final BooruConfig profile;
  void remove() => state = [];
}

class _FileSystem implements AppFileSystem {
  final memory = MemoryAppFileSystem();
  Completer<void>? gate;
  final started = Completer<void>();
  bool fail = false;
  @override
  Future<String?> getTemporaryPath() async {
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (fail) throw const FileSystemException('storage failed');
    return memory.getTemporaryPath();
  }

  @override
  Future<void> createDirectory(String path, {bool recursive = false}) =>
      memory.createDirectory(path, recursive: recursive);
  @override
  Future<List<FileSystemEntry>> listDirectory(
    String path, {
    bool recursive = false,
    bool followLinks = true,
  }) => memory.listDirectory(
    path,
    recursive: recursive,
    followLinks: followLinks,
  );
  @override
  Future<void> writeBytes(String path, Uint8List bytes) =>
      memory.writeBytes(path, bytes);
  @override
  Future<DateTime> lastModified(String path) => memory.lastModified(path);
  @override
  Future<void> deleteDirectory(String path, {bool recursive = false}) =>
      memory.deleteDirectory(path, recursive: recursive);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('shares one Group document and suppresses repeated taps', (
    tester,
  ) async {
    final fs = _FileSystem();
    final response = Completer<ShareResult>();
    final received = Completer<ShareParams>();
    var calls = 0;
    final fixture = await _mount(
      tester,
      fs,
      ShareActionAdapter((params) {
        calls++;
        received.complete(params);
        return response.future;
      }),
      loadedTitle: 'Summer__Collection',
    );
    await _openGroupShare(tester);
    await tester.tap(find.byTooltip('Share entire collection link file'));
    await tester.pump();
    final params = await received.future;
    expect(params.files, hasLength(1));
    expect(params.uri, isNull);
    expect(params.text, 'Summer Collection on Reading Profile');
    final file = params.files!.single;
    expect(file.name, 'reading-profile-pool-42.bslink');
    expect(file.mimeType, BoorusamaLinkFile.mimeType);
    final document = BoorusamaLinkFile.decode(
      await fs.memory.readBytes(file.path),
    );
    final link = BoorusamaGroupLink.parse(document.uri.toString());
    expect(link.reference, fixture.reference);
    expect(document.uri.toString(), isNot(contains('fixture-secret')));
    expect(document.uri.toString(), isNot(contains(fixture.profile.id)));
    expect(document.uri.toString(), isNot(contains('cover')));
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey(SharePayloadId.groupLinkFile)),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Share entire collection link file'));
    expect(calls, 1);
    response.complete(const ShareResult('', ShareResultStatus.success));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'Pixiv Timeline shares the Work file, artwork URL and artwork ID',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final fs = _FileSystem();
      final shared = <ShareParams>[];
      final copied = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final fixture = await _mount(
        tester,
        fs,
        ShareActionAdapter((params) async {
          shared.add(params);
          return const ShareResult('', ShareResultStatus.success);
        }),
        pixiv: true,
        loadedTitle: 'Blue Hour',
        author: 'Aki',
      );
      await tester.tap(find.byType(GroupLinkShareButton));
      await tester.pumpAndSettle();
      expect(find.text('Post Link'), findsOneWidget);
      expect(find.text('Post ID'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Pool Link'), findsNothing);
      expect(find.byTooltip('Share current post link file'), findsNothing);

      await tester.tap(find.byTooltip('Copy Post Link'));
      await tester.pump();
      await tester.tap(find.byTooltip('Copy Post ID'));
      await tester.pump();
      await tester.tap(find.byTooltip('Share Booru Link'));
      await tester.pump();
      await tester.tap(find.byTooltip('Share Post ID'));
      await tester.pump();
      await tester.tap(find.byTooltip('Share entire collection link file'));
      await tester.pump();

      const artwork = 'https://www.pixiv.net/artworks/42';
      expect(copied, [artwork, '42']);
      expect(shared, hasLength(3));
      expect(shared[0].uri, Uri.parse(artwork));
      expect(shared[1].text, '42');
      expect(shared[2].text, 'Blue Hour by Aki on Pixiv');
      final file = shared[2].files!.single;
      expect(file.name, 'reading-profile-work-42.bslink');
      final attached = BoorusamaLinkFile.decode(
        await fs.memory.readBytes(file.path),
      );
      expect(
        BoorusamaGroupLink.parse(attached.uri.toString()).reference,
        fixture.reference,
      );

      final link = tester.widget<SharePayloadTile>(
        find.byKey(const ValueKey(SharePayloadId.booruLink)),
      );
      final id = tester.widget<SharePayloadTile>(
        find.byKey(const ValueKey(SharePayloadId.postId)),
      );
      fixture.profiles.remove();
      await tester.pump();
      link.onShare!();
      id.onCopy!();
      await tester.pump();
      expect(find.text('Post ID'), findsNothing);
      expect(shared, hasLength(3));
      expect(copied, [artwork, '42']);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('profile removal during filesystem preparation cancels handoff', (
    tester,
  ) async {
    final fs = _FileSystem()..gate = Completer<void>();
    var calls = 0;
    final fixture = await _mount(
      tester,
      fs,
      ShareActionAdapter((_) async {
        calls++;
        return const ShareResult('', ShareResultStatus.success);
      }),
    );
    await _openGroupShare(tester);
    await tester.tap(find.byTooltip('Share entire collection link file'));
    await fs.started.future;
    fixture.profiles.remove();
    await tester.pump();
    fs.gate!.complete();
    await tester.pump();
    await tester.pump();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('saved Pixiv Work creator is available without a metadata read', (
    tester,
  ) async {
    final captions = <String?>[];
    await _mount(
      tester,
      _FileSystem(),
      ShareActionAdapter((params) async {
        captions.add(params.text);
        return const ShareResult('', ShareResultStatus.success);
      }),
      pixiv: true,
      storedAuthor: 'Aki',
    );
    await tester.tap(find.byType(GroupLinkShareButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Share entire collection link file'));
    await tester.pumpAndSettle();
    expect(captions, ['Saved Work by Aki on Pixiv']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('storage failure reports an error and permits retry', (
    tester,
  ) async {
    final fs = _FileSystem()..fail = true;
    var calls = 0;
    await _mount(
      tester,
      fs,
      ShareActionAdapter((_) async {
        calls++;
        return const ShareResult('', ShareResultStatus.success);
      }),
    );
    await _openGroupShare(tester);
    await tester.tap(find.byTooltip('Share entire collection link file'));
    await tester.pump();
    await tester.pump();
    expect(calls, 0);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey(SharePayloadId.groupLinkFile)),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

Future<({BooruConfig profile, ContentReference reference, _Profiles profiles})>
_mount(
  WidgetTester tester,
  _FileSystem fs,
  ShareActionAdapter adapter, {
  String? loadedTitle,
  String? author,
  String? storedAuthor,
  bool pixiv = false,
}) async {
  final engine = pixiv ? BooruType.pixiv : BooruType.danbooru;
  final profile = BooruConfig.fromJson({
    ...testProfile.toJson(),
    'booruId': engine.id,
    'booruIdHint': engine.id,
    'url': pixiv ? 'https://www.pixiv.net' : 'https://group.example',
    'name': 'Reading Profile',
    'apiKey': 'fixture-secret',
  });
  final reference = const ContentReferenceCodec().parse(
    engine: engine,
    site: Uri.parse(profile.url),
    kind: ContentKind.group,
    sourceKey: pixiv ? 'work:42' : 'pool:42',
  );
  final binding = ViewerSourceBinding(profile);
  final entry = GroupViewerEntry(
    summary: ContentGroupSummary(reference: reference, title: 'Group'),
    storedDetails: storedAuthor == null
        ? null
        : ContentGroupDetails(
            summary: ContentGroupSummary(
              reference: reference,
              title: 'Saved Work',
            ),
            creators: [CreatorRef(displayName: storedAuthor)],
          ),
    occurrenceId: 'private-local-id',
    source: binding,
  );
  late _Profiles profiles;
  final harness = FollowingTopicHarness(
    profiles: [profile],
    overrides: [
      booruConfigProvider.overrideWith(() => profiles = _Profiles(profile)),
      contentEffectivePolicyProvider.overrideWith(
        (ref, id) => const AsyncData('test'),
      ),
      appFileSystemProvider.overrideWithValue(fs),
      groupLinkShareAdapterProvider.overrideWithValue(adapter),
      if (pixiv)
        mediaGroupProvider.overrideWith(
          (ref, entry) => MediaGroupState(
            members: GroupMembersState(
              members: const [],
              resolved: const {},
              generation: 0,
            ),
          ),
        ),
      groupDetailsProvider.overrideWith((ref, key) {
        if (loadedTitle == null) {
          throw StateError('Share must not fetch metadata');
        }
        return ContentGroupDetails(
          summary: ContentGroupSummary(
            reference: reference,
            title: loadedTitle,
          ),
          creators: author == null ? null : [CreatorRef(displayName: author)],
        );
      }),
    ],
  );
  addTearDown(harness.dispose);
  await harness.pump(
    tester,
    Scaffold(
      body: GroupViewerScope(
        entry: entry,
        child: Consumer(
          builder: (context, ref, _) {
            final access = loadedTitle == null
                ? null
                : ref.watch(viewerSourceAccessProvider(binding));
            if (access != null) {
              ref.watch(
                groupDetailsProvider(
                  GroupMetadataKey(reference: reference, access: access.key),
                ),
              );
            }
            return pixiv && loadedTitle != null
                ? PixivWorkTimeline(entry: entry)
                : const Center(child: GroupLinkShareButton());
          },
        ),
      ),
    ),
  );
  return (profile: profile, reference: reference, profiles: profiles);
}

Future<void> _openGroupShare(WidgetTester tester) async {
  await tester.tap(find.byType(GroupLinkShareButton));
  await tester.pumpAndSettle();
  expect(find.text('Link File'), findsOneWidget);
  expect(find.text('Pool Link'), findsOneWidget);
  expect(find.byType(ConfigAwareWebsiteLogo), findsOneWidget);
  expect(find.text('Post ID'), findsNothing);
  expect(find.byTooltip('Share current post link file'), findsNothing);
}
