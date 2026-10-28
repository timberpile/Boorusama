import 'dart:async';

import 'package:boorusama/core/search/following_topics/src/widgets/edit_following_topic_dialog.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import 'following_topic_test_utils.dart';

// Query, profile, raw/typed input, and post-return cases now live in
// update_original_topic_flow_test.dart, using ordinary Search and persistence.
void main() {
  late FollowingTopicHarness harness;
  late List<
    ({
      String query,
      String profileId,
      String? name,
      bool automatic,
      SearchQueryStructure? structure,
    })
  >
  saves;
  Object? failure;
  Completer<void>? gate;
  setUp(() {
    harness = FollowingTopicHarness();
    saves = [];
    failure = null;
    gate = null;
  });
  tearDown(() => harness.dispose());

  Future<void> open(WidgetTester tester, {bool missingProfile = false}) async {
    final topic = topicFixture(query: '( cat ~ dog ) source:"a b"');
    await harness.pump(
      tester,
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showEditFollowingTopicDialog(
              context,
              topic: topic,
              profiles: missingProfile ? [] : [testProfile, otherTestProfile],
              trackingSupported: (_) => true,
              onSave: (profile, query, name, automatic, structure) async {
                if (gate case final pending?) await pending.future;
                if (failure case final error?) {
                  Error.throwWithStackTrace(error, StackTrace.current);
                }
                saves.add((
                  query: query,
                  profileId: profile.id,
                  name: name,
                  automatic: automatic,
                  structure: structure,
                ));
                return (topic: topic, refresh: null);
              },
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await settle(tester);
  }

  testWidgets(
    'settings edit retains name and Auto Update without a separate query or profile picker',
    (tester) async {
      await open(tester);
      expect(find.text('Edit Query'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Draft name');
      await tester.tap(find.byType(SwitchListTile));
      await tester.tap(find.text('Save'));
      await drain(tester);
      await settle(tester);
      expect(saves.single.name, 'Draft name');
      expect(saves.single.profileId, testProfile.id);
      expect(saves.single.automatic, isFalse);
      expect(saves.single.query, '( cat ~ dog ) source:"a b"');
      expect(saves.single.structure, isNull);
      expect(find.text('Edit Topic'), findsNothing);
    },
  );

  testWidgets('Cancel never writes the settings draft', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Unsaved');
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(saves, isEmpty);
  });

  testWidgets('missing profile blocks settings Save', (tester) async {
    await open(tester, missingProfile: true);
    expect(
      find.text('Choose an available profile before saving.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    expect(saves, isEmpty);
  });

  for (final error in [
    DuplicateFollowingTopicException(),
    MissingFollowingTopicProfileException(),
    StaleFollowingTopicEditException(),
    StateError('disk'),
  ]) {
    testWidgets(
      'settings ${error.runtimeType} leaves fields available for retry',
      (tester) async {
        await open(tester);
        await tester.enterText(find.byType(TextField), 'Retry name');
        failure = error;
        await tester.tap(find.text('Save'));
        await drain(tester);
        await settle(tester);
        expect(find.text('Edit Topic'), findsOneWidget);
        expect(saves, isEmpty);
        failure = null;
        await tester.tap(find.text('Save'));
        await drain(tester);
        await settle(tester);
        expect(saves.single.name, 'Retry name');
      },
    );
  }

  testWidgets(
    'repeated settings Save and Back are blocked during persistence',
    (tester) async {
      await open(tester);
      gate = Completer<void>();
      final save = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed!;
      save();
      save();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Edit Topic'), findsOneWidget);
      gate!.complete();
      await drain(tester);
      await settle(tester);
      expect(saves, hasLength(1));
    },
  );

  testWidgets('settings fit at 320dp with enlarged text and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.7;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await open(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.enterText(find.byType(TextField), 'Name');
    await settle(tester);
    expect(tester.getRect(find.text('Save')).bottom, lessThanOrEqualTo(460));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Save'));
    await drain(tester);
    expect(saves.single.name, 'Name');
  });
}
