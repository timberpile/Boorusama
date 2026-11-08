import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/details/src/widgets/group_viewer_scope.dart';
import 'package:boorusama/core/posts/links/boorusama_group_link.dart';
import 'package:boorusama/core/posts/links/boorusama_link_file.dart';
import 'package:boorusama/core/posts/links/share_group_link_button.dart';
import 'package:boorusama/core/posts/shares/src/share_action_adapter.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
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
    );
    await tester.tap(find.byType(GroupLinkShareButton));
    await tester.pump();
    final params = await received.future;
    expect(params.files, hasLength(1));
    expect(params.uri, isNull);
    expect(params.text, isNull);
    final file = params.files!.single;
    expect(file.name, 'boorusama-group-pool-42.bslink');
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
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(GroupLinkShareButton));
    expect(calls, 1);
    response.complete(const ShareResult('', ShareResultStatus.success));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

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
    await tester.tap(find.byType(GroupLinkShareButton));
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
    await tester.tap(find.byType(GroupLinkShareButton));
    await tester.pump();
    await tester.pump();
    expect(calls, 0);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNotNull,
    );
    final message = tester
        .element(find.byType(GroupLinkShareButton))
        .t
        .post
        .action
        .operation_failed;
    expect(find.text(message), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

Future<({BooruConfig profile, ContentReference reference, _Profiles profiles})>
_mount(WidgetTester tester, _FileSystem fs, ShareActionAdapter adapter) async {
  final profile = BooruConfig.fromJson({
    ...testProfile.toJson(),
    'booruId': BooruType.danbooru.id,
    'booruIdHint': BooruType.danbooru.id,
    'url': 'https://group.example',
    'apiKey': 'fixture-secret',
  });
  final reference = const ContentReferenceCodec().parse(
    engine: BooruType.danbooru,
    site: Uri.parse(profile.url),
    kind: ContentKind.group,
    sourceKey: 'pool:42',
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
    ],
  );
  addTearDown(harness.dispose);
  await harness.pump(
    tester,
    Scaffold(
      body: GroupViewerScope(
        entry: GroupViewerEntry(
          summary: ContentGroupSummary(reference: reference, title: 'Group'),
          occurrenceId: 'private-local-id',
          source: ViewerSourceBinding(profile),
        ),
        child: const Center(child: GroupLinkShareButton()),
      ),
    ),
  );
  return (profile: profile, reference: reference, profiles: profiles);
}
