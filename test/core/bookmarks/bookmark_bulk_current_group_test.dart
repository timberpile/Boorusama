import 'dart:async';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_multi_selection.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';

import '../search/following_topics/topic_test_utils.dart';

void main() {
  const actionKey = Key('bookmark-remove-current-group');

  Widget app({
    String? groupId,
    required List<Post> posts,
    required _RecordingNotifier notifier,
    required Future<void> Function() onCompleted,
  }) => ProviderScope(
    overrides: [bookmarkProvider.overrideWith(() => notifier)],
    child: BooruLocalization(
      child: MaterialApp(
        home: OKToast(
          child: Scaffold(
            body: BookmarkMultiSelectionMenu(
              posts: posts,
              config: BooruConfig.empty.auth,
              currentGroupId: groupId,
              onCompleted: onCompleted,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('All Bookmarks keeps both pickers and no direct Remove', (
    tester,
  ) async {
    final notifier = _RecordingNotifier();
    await tester.pumpWidget(
      app(
        posts: [testSearchPost(42, DateTime.utc(2026))],
        notifier: notifier,
        onCompleted: () async => fail('No removal was requested'),
      ),
    );
    expect(find.byKey(actionKey), findsNothing);
    expect(find.byType(KurumiPopupMenuItem), findsNWidgets(2));
    expect(find.text('Add to'), findsOneWidget);
    expect(find.text('Remove from'), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    expect(notifier.calls, 0);
  });

  testWidgets('rapid direct removal dispatches only one pending operation', (
    tester,
  ) async {
    final notifier = _RecordingNotifier();
    await tester.pumpWidget(
      app(
        groupId: '550e8400-e29b-41d4-a716-446655440000',
        posts: [testSearchPost(42, DateTime.utc(2026))],
        notifier: notifier,
        onCompleted: () async => fail('Controlled failure cannot complete'),
      ),
    );
    final action = tester.widget<KurumiPopupMenuItem>(find.byKey(actionKey));
    action.onTap.call();
    action.onTap.call();
    expect(notifier.calls, 1);
    notifier.release.complete();
    await tester.pumpAndSettle();
    dismissAllToast(showAnim: false);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'direct removal captures group and mixed-source identity without a picker',
    (
      tester,
    ) async {
      final notifier = _RecordingNotifier();
      final posts = [
        for (final host in ['first.test', 'second.test'])
          testSearchPost(42, DateTime.utc(2026)).copyWith(
            origin: PostOrigin.fromSource(
              booruType: BooruConfig.empty.auth.booruType,
              booruId: BooruConfig.empty.booruId,
              source: 'https://$host',
            ),
          ),
      ];
      var completed = 0;
      await tester.pumpWidget(
        app(
          groupId: '550e8400-e29b-41d4-a716-446655440000',
          posts: posts,
          notifier: notifier,
          onCompleted: () async {
            completed++;
          },
        ),
      );
      expect(find.byType(KurumiPopupMenuItem), findsNWidgets(3));
      expect(find.text('Add to'), findsOneWidget);
      expect(find.text('Remove from'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
      tester.widget<KurumiPopupMenuItem>(find.byKey(actionKey)).onTap.call();
      await tester.pump();
      posts.clear();
      expect(notifier.calls, 1);
      expect(notifier.groupId, '550e8400-e29b-41d4-a716-446655440000');
      expect(notifier.posts.map((post) => post.origin.sourceHost), [
        'first.test',
        'second.test',
      ]);
      expect(find.byType(AlertDialog), findsNothing);
      notifier.release.complete();
      await tester.pump();
      await tester.pump();
      expect(
        completed,
        0,
        reason: 'failure must not report successful completion',
      );
      dismissAllToast(showAnim: false);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

class _RecordingNotifier extends BookmarkLibraryNotifier {
  final release = Completer<void>();
  var calls = 0;
  String? groupId;
  List<Post> posts = const [];

  // The dispatch test needs no repositories. Existing provider tests exercise
  // the real membership/Undo operation; add end-to-end menu coverage locally.
  @override
  Future<Never> build() => Completer<Never>().future;

  @override
  Future<Never> removePostsFromGroup(
    BooruConfigAuth config,
    Iterable<Post> selected,
    String target,
  ) async {
    calls++;
    groupId = target;
    posts = List.unmodifiable(selected);
    await release.future;
    throw StateError('Controlled mutation failure');
  }
}
