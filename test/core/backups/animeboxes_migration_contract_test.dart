import '../search/subscriptions/subscription_test_utils.dart';
import 'dart:convert';
import 'dart:io';

import 'package:boorusama/boorus/danbooru/danbooru.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_source_integrity_validator.dart';
import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/pinned_search_backup_codec.dart';
import 'package:boorusama/core/backups/sources/pinned_search_backup_data.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/backups/utils/json_handler.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/src/data/hive/tag_repository.dart';
import 'package:boorusama/core/blacklists/src/data/hive/tag_hive_object.dart';
import 'package:boorusama/core/blacklists/types.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_hive_object.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart';
import 'package:boorusama/core/search/subscriptions/src/data/providers.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/core/backups/export_import/import/import_flow_page.dart';
import 'package:boorusama/core/backups/export_import/widgets/import_action_editor.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const _localProfileId = 'a0000000-0000-4000-8000-000000000001';
const _localGroupId = 'a0000000-0000-4000-8000-000000000002';
const _localFolderId = 'a0000000-0000-4000-8000-000000000003';

void main() {
  late Directory fixtures;
  late Map<String, String> packagePaths;

  setUpAll(() async {
    fixtures = await Directory.systemTemp.createTemp('animeboxes_contract_');
    final input = File('${fixtures.path}/source.csv');
    await input.writeAsString(
      File(
        'packages/boorusama_cli/test/migrations/animeboxes/fixtures/complete.csv',
      ).readAsStringSync(),
    );
    final namedInput = File('${fixtures.path}/folder_names.csv');
    await namedInput.writeAsString(
      File(
        'packages/boorusama_cli/test/migrations/animeboxes/fixtures/folder_names.csv',
      ).readAsStringSync(),
    );
    final namedNormalized = '${fixtures.path}/folder_names.json';
    await _cli([
      'normalize',
      '--input',
      namedInput.path,
      '--output',
      namedNormalized,
    ]);
    await _cli([
      'export',
      '--input',
      namedNormalized,
      '--output-dir',
      '${fixtures.path}/named',
    ]);
    final normalized = '${fixtures.path}/normalized.json';
    await _cli(['normalize', '--input', input.path, '--output', normalized]);
    final original =
        jsonDecode(File(normalized).readAsStringSync()) as Map<String, dynamic>;
    packagePaths = {};
    for (final port in ['', ':8443', ':443', 'empty']) {
      final document = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
      if (port == 'empty') {
        document['bookmarks'] = [];
        document['blacklist'] = [];
        document['pinnedSearchFolders'] = [];
      } else if (port.isEmpty) {
        final bookmark =
            Map<String, dynamic>.from(
                (document['bookmarks'] as List).single as Map,
              )
              ..['postId'] = 43
              ..['postUrl'] = 'https://danbooru.donmai.us/posts/43'
              ..['sourcePosition'] = 1;
        (document['bookmarks'] as List).add(bookmark);
        final groups = document['pinnedSearchFolders'] as List;
        final folder = groups.single as Map;
        final search = Map<String, dynamic>.from(
          (folder['searches'] as List).single as Map,
        );
        // A valid AnimeBoxes filter-only pin has blank main text.
        final firstSearch = (folder['searches'] as List).single as Map;
        firstSearch['query'] = '';
        firstSearch['extraParams'] = {
          'extra_tags': 'rating:general order:score',
          'danbooru2_is_has': 'rating:general',
          'danbooru2_order': 'order:score',
        };
        Map<String, dynamic> pin(int index, String query) => {
          ...search,
          'id': 'b0000000-0000-4000-8000-00000000000$index',
          'query': query,
          'position': index,
          'name': null,
        };
        (folder['searches'] as List).add(pin(1, 'folder_second'));
        groups.add({
          'kind': 'folder',
          'id': 'b0000000-0000-4000-8000-000000000007',
          'name': 'Second folder',
          'sourcePosition': 1,
          'searches': [pin(2, 'side_folder')],
        });
        groups.add({
          'kind': 'home',
          'id': null,
          'name': null,
          'sourcePosition': 2,
          'searches': [pin(3, 'home_z'), pin(4, 'home_a')],
        });
      } else {
        final url = 'http://danbooru.donmai.us$port';
        (document['profiles'] as List).single['url'] = url;
        (document['bookmarks'] as List).single['postUrl'] = '$url/posts/42';
        (document['pinnedSearchFolders'] as List).single['searches'][0]['url'] =
            url;
      }
      final suffix = port.isEmpty
          ? 'main'
          : port == 'empty'
          ? 'empty'
          : port.substring(1);
      final input = File('${fixtures.path}/$suffix.json');
      await input.writeAsString(jsonEncode(document));
      final output = '${fixtures.path}/$suffix';
      await _cli(['export', '--input', input.path, '--output-dir', output]);
      packagePaths[port] = '$output/animeboxes.bsexport';
    }
  });
  tearDownAll(() => fixtures.delete(recursive: true));

  testWidgets(
    'imports actual source folder labels, duplicates, and unnamed folders',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.runAsync(() async {
        final harness = await _Harness.create(populated: false);
        try {
          final notifier = harness.container.read(importFlowProvider.notifier);
          await notifier.load('${fixtures.path}/named/animeboxes.bsexport');
          var state = harness.container.read(importFlowProvider);
          expect(state.status, ImportFlowStatus.review);
          notifier.chooseProfileMapping(
            ProfileSiteKey.fromReference(
              state.profileMappings.single.reference,
            ),
            _localProfileId,
          );
          expect(
            harness.container.read(importFlowProvider).preflight!.isValid,
            true,
          );
          await notifier.apply(context);
          state = harness.container.read(importFlowProvider);
          expect(
            state.status,
            ImportFlowStatus.complete,
            reason: '${state.error}',
          );
          final organization = await harness.searches.getOrganization();
          expect(organization.folders.map((folder) => folder.name), [
            'Imported Searches',
            'Folder, café',
            'Folder, café (2)',
            'Imported folder 3',
          ]);
          expect(
            organization.folders.map((folder) => folder.searchIds.length),
            [0, 1, 1, 1],
          );
          final pins = await harness.searches.getAll();
          expect(pins.map((pin) => pin.query), [
            'synthetic_query_0 order:score',
            'synthetic_query_1 order:score',
            'synthetic_query_2 order:score',
          ]);
          expect(pins.map((pin) => pin.name), everyElement('Quoted "title"'));
        } finally {
          await harness.close();
        }
      });
    },
  );

  test(
    'CLI packages pass current reader, codecs, and source integrity checks',
    () async {
      for (final port in ['', ':8443', ':443']) {
        final staged = await const ExportPackageReader(
          fs: IoFileSystem(),
        ).stage(packagePaths[port]!);
        try {
          expect(staged.manifest.containsCredentials, false);
          expect(staged.manifest.preset, ExportSelectionMode.custom);
          expect(staged.manifest.sources.map((source) => source.id), [
            'bookmarks',
            'blacklisted_tags',
            'pinned_searches',
          ]);
          BookmarkBackupData? bookmarks;
          PinnedSearchBackupData? searches;
          for (final source in staged.manifest.sources) {
            final payload = decodeData(
              data: File(
                staged.pathFor(source.parts.single.path),
              ).readAsStringSync(),
            );
            final data = switch (source.id) {
              'bookmarks' => bookmarks = BookmarkBackupCodec().parse(payload),
              'pinned_searches' => searches = PinnedSearchBackupCodec().parse(
                payload,
              ),
              _ => ListHandler<BlacklistedTag>(
                parser: BlacklistedTag.fromJson,
                encoder: (tag) => tag.toJson(),
              ).parse(payload),
            };
            expect(
              const ImportSourceIntegrityValidator().validate(
                sourceId: source.id,
                packageSchemaVersion: source.schemaVersion,
                supportedSchemaVersion: source.id == 'bookmarks' ? 4 : 1,
                selection: source.selection!,
                itemRecommendations: source.itemRecommendedActions,
                data: data,
              ),
              isEmpty,
            );
            expect(
              source.recommendedAction,
              source.id == 'blacklisted_tags'
                  ? ImportAction.skip
                  : ImportAction.configureItems,
            );
            expect(source.selection!.kind, ExportNodeSelectionKind.explicit);
            if (source.id == 'pinned_searches') {
              expect(source.selection!.childIds, isNot(contains('home')));
            }
          }
          expect(
            bookmarks!.bookmarks.map((bookmark) => bookmark.identity.site),
            everyElement('danbooru.donmai.us$port'),
          );
          expect(
            bookmarks.groups.single.bookmarkIds,
            port.isEmpty ? [1, 2] : [1],
          );
          expect(
            searches!.records.first.profile.id,
            matches(RegExp(r'^[0-9a-f-]{36}$')),
          );
          if (port.isEmpty) {
            expect(bookmarks.bookmarks.map((bookmark) => bookmark.postId), [
              42,
              43,
            ]);
            expect(
              bookmarks.bookmarks
                  .map((bookmark) => bookmark.originalUrl)
                  .toSet(),
              hasLength(1),
            );
            expect(searches.folders.map((folder) => folder.name), [
              'Folder, café',
              'Second folder',
            ]);
            expect(searches.homeSearchIds, [
              'b0000000-0000-4000-8000-000000000003',
              'b0000000-0000-4000-8000-000000000004',
            ]);
          }
        } finally {
          await staged.dispose();
        }
      }
    },
  );

  test(
    'empty migration payloads still pass current source contracts',
    () async {
      final staged = await const ExportPackageReader(
        fs: IoFileSystem(),
      ).stage(packagePaths['empty']!);
      try {
        for (final source in staged.manifest.sources) {
          final payload = decodeData(
            data: File(
              staged.pathFor(source.parts.single.path),
            ).readAsStringSync(),
          );
          final data = switch (source.id) {
            'bookmarks' => BookmarkBackupCodec().parse(payload),
            'pinned_searches' => PinnedSearchBackupCodec().parse(payload),
            _ => ListHandler<BlacklistedTag>(
              parser: BlacklistedTag.fromJson,
              encoder: (tag) => tag.toJson(),
            ).parse(payload),
          };
          expect(
            const ImportSourceIntegrityValidator().validate(
              sourceId: source.id,
              packageSchemaVersion: source.schemaVersion,
              supportedSchemaVersion: source.id == 'bookmarks' ? 4 : 1,
              selection: source.selection!,
              itemRecommendations: source.itemRecommendedActions,
              data: data,
            ),
            isEmpty,
          );
          switch (data) {
            case BookmarkBackupData():
              expect(data.bookmarks, isEmpty);
            case PinnedSearchBackupData():
              expect(data.records, isEmpty);
              expect(data.folders, isEmpty);
              expect(data.homeSearchIds, isEmpty);
            case List<BlacklistedTag>():
              expect(data, isEmpty);
          }
        }
      } finally {
        await staged.dispose();
      }
    },
  );

  testWidgets(
    'Merge into retains unresolved selection and applies the chosen group',
    (tester) async {
      late _Harness harness;
      await tester.runAsync(() async {
        harness = await _Harness.create(populated: true);
        await harness.groups.createGroup(
          'Other target',
          id: 'a0000000-0000-4000-8000-000000000004',
        );
        await harness.bookmarks.addBookmarkWithBookmarks([
          Bookmark.empty.copyWith(
            originalUrl: 'https://local.example/duplicate.jpg',
            sourceUrl: 'https://danbooru.donmai.us',
            postId: () => 42,
          ),
        ]);
        await harness.container
            .read(bookmarkProvider.notifier)
            .syncActiveTargetFromSettings();
        final notifier = harness.container.read(importFlowProvider.notifier);
        await notifier.load(packagePaths['']!);
        final pins = harness.container
            .read(importFlowProvider)
            .resolved!
            .sources
            .singleWhere((s) => s.id == 'pinned_searches');
        notifier.replaceSource(pins.copyWith(action: ImportAction.skip));
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(harness.close);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    final state = ref.watch(importFlowProvider);
                    final source = state.resolved!.sources.singleWhere(
                      (s) => s.id == 'bookmarks',
                    );
                    return ListView(
                      children: [
                        ImportActionEditor(
                          proposed: state.proposed!.sources.singleWhere(
                            (s) => s.id == 'bookmarks',
                          ),
                          resolved: source,
                          onChanged: ref
                              .read(importFlowProvider.notifier)
                              .replaceSource,
                          sourceLabel: (_) => 'Bookmark groups',
                          itemLabel: (_) => 'AnimeBoxes',
                          targetLabel: (id) => id == 'group:$_localGroupId'
                              ? 'Local bookmarks'
                              : 'Other target',
                        ),
                        ImportReviewValidation(
                          preflight: state.preflight!,
                          sourceNames: const {'bookmarks': 'Bookmark groups'},
                          itemLabels: state.itemLabels,
                          onWarningsAcknowledged: ref
                              .read(importFlowProvider.notifier)
                              .acknowledgeWarnings,
                          onApply: () => ref
                              .read(importFlowProvider.notifier)
                              .apply(context),
                          onDone: () {},
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> action(String label) async {
        final selected = harness.container
            .read(importFlowProvider)
            .resolved!
            .sources
            .singleWhere((s) => s.id == 'bookmarks')
            .items
            .single
            .action;
        final selectedLabel = {
          ImportAction.copy: 'Copy',
          ImportAction.mergeIntoTarget: 'Merge into...',
          ImportAction.skip: 'Skip',
        }[selected]!;
        await tester.tap(find.text(selectedLabel).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await action('Merge into...');
      expect(tester.takeException(), isNull);
      expect(find.text('Target'), findsOneWidget);
      expect(find.text('Merge into...'), findsOneWidget);
      expect(
        find.text('Choose a valid target for AnimeBoxes.'),
        findsOneWidget,
      );
      expect(
        harness.container
            .read(importFlowProvider)
            .preflight!
            .sourceSummaries
            .containsKey('bookmarks'),
        false,
      );
      expect(
        harness.container.read(importFlowProvider).preflight!.isValid,
        false,
      );
      expect(
        harness.container
            .read(importFlowProvider)
            .preflight!
            .errors
            .map((e) => e.code),
        contains('invalid_merge_target'),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );
      await tester.runAsync(() async {
        expect(await harness.groups.getGroups(), hasLength(2));
        expect(
          await harness.bookmarks.getAllBookmarksOrThrow(
            imageUrlResolver: (_) => const DefaultImageUrlResolver(),
          ),
          hasLength(2),
        );
      });
      Future<void> target(String label) async {
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await target('Other target');
      expect(
        harness.container.read(importFlowProvider).preflight!.isValid,
        true,
      );
      await target('Local bookmarks');
      await action('Skip');
      expect(find.text('Target'), findsNothing);
      await action('Merge into...');
      expect(
        harness.container
            .read(importFlowProvider)
            .resolved!
            .sources
            .singleWhere((s) => s.id == 'bookmarks')
            .items
            .single
            .targetId,
        isNull,
      );
      expect(
        harness.container.read(importFlowProvider).preflight!.isValid,
        false,
      );
      await target('Local bookmarks');
      expect(
        harness.container
            .read(importFlowProvider)
            .preflight!
            .sourceSummaries['bookmarks']!
            .entitySummaries['bookmark']!
            .created,
        1,
      );
      await tester.runAsync(() async {
        expect(await harness.groups.getGroups(), hasLength(2));
        final context = tester.element(find.byType(ImportActionEditor));
        await harness.container
            .read(importFlowProvider.notifier)
            .apply(context);
        final state = harness.container.read(importFlowProvider);
        expect(
          state.status,
          ImportFlowStatus.complete,
          reason: '${state.error}',
        );
        final groups = await harness.groups.getGroups();
        expect(groups, hasLength(2));
        final merged = groups.singleWhere((g) => g.id == _localGroupId);
        expect(merged.name, 'Local bookmarks');
        expect(merged.bookmarkIds, hasLength(3));
        expect(
          groups
              .singleWhere(
                (g) => g.id == 'a0000000-0000-4000-8000-000000000004',
              )
              .bookmarkIds,
          isEmpty,
        );
        final bookmarks = await harness.bookmarks.getAllBookmarksOrThrow(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        );
        expect(bookmarks.map((b) => b.postId).toSet(), {42, 43, 99});
        expect(bookmarks, hasLength(3));
      });
    },
  );

  for (final populated in [false, true]) {
    testWidgets(
      'current review maps profiles and applies safely to ${populated ? 'populated' : 'empty'} stores',
      (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.runAsync(() async {
          final harness = await _Harness.create(populated: populated);
          try {
            final notifier = harness.container.read(
              importFlowProvider.notifier,
            );
            await notifier.load(packagePaths['']!);
            var state = harness.container.read(importFlowProvider);
            expect(
              state.status,
              ImportFlowStatus.review,
              reason: state.error is InvalidBackupFormatException
                  ? (state.error! as InvalidBackupFormatException).details
                  : '${state.error}',
            );
            expect(state.proposed!.warnings, isEmpty);
            final pins = state.proposed!.sources.singleWhere(
              (source) => source.id == 'pinned_searches',
            );
            expect(pins.kind, ImportSourceKind.collection);
            expect(pins.defaultAction, ImportAction.configureItems);
            expect(
              pins.availableActions,
              isNot(contains(ImportAction.replace)),
            );
            expect(
              state.resolved!.sources
                  .singleWhere((source) => source.id == 'blacklisted_tags')
                  .action,
              ImportAction.skip,
            );
            expect(state.profileMappings.single.profileId, _localProfileId);
            expect(state.profileMappings.single.candidateIds, {
              _localProfileId,
            });
            expect(state.preflight!.isValid, true);
            expect(state.preflight!.errors, isEmpty);
            expect(
              await harness.searches.getAll(),
              hasLength(populated ? 1 : 0),
            );
            final profilesBefore = await harness.profiles.getAll();
            notifier.chooseProfileMapping(
              ProfileSiteKey.fromReference(
                state.profileMappings.single.reference,
              ),
              _localProfileId,
            );
            state = harness.container.read(importFlowProvider);
            expect(state.preflight!.errors, isEmpty);
            expect(state.preflight!.isValid, true);
            expect(state.preflight!.summary.deleted, 0);
            await notifier.apply(context);
            state = harness.container.read(importFlowProvider);
            expect(
              state.status,
              ImportFlowStatus.complete,
              reason: state.error is InvalidBackupFormatException
                  ? (state.error! as InvalidBackupFormatException).details
                  : '${state.error}',
            );
            expect(await harness.profiles.getAll(), profilesBefore);
            expect(
              (await harness.blacklist.getBlacklist()).map((tag) => tag.name),
              ['local_rule'],
            );
            final bookmarks = await harness.bookmarks.getAllBookmarksOrThrow(
              imageUrlResolver: (_) => const DefaultImageUrlResolver(),
            );
            expect(
              bookmarks.map((bookmark) => bookmark.postId),
              containsAll([42, 43, if (populated) 99]),
            );
            expect(bookmarks, hasLength(populated ? 3 : 2));
            final groups = await harness.groups.getGroups();
            final imported = groups.singleWhere(
              (group) => group.name == 'AnimeBoxes',
            );
            expect(imported.bookmarkIds, {
              for (final bookmark in bookmarks)
                if (bookmark.postId != 99) bookmark.id,
            });
            if (populated) {
              expect(
                (await harness.groups.getGroup(_localGroupId))!.bookmarkIds,
                {bookmarks.singleWhere((bookmark) => bookmark.postId == 99).id},
              );
            }
            await _expectSearchOrder(harness, populated: populated);
            final extra = await harness.searches.create(
              profileId: _localProfileId,
              query: 'local_only_in_imported_folder',
              name: null,
            );
            final firstOrganization = await harness.searches.getOrganization();
            final firstFolderId = firstOrganization.folders
                .singleWhere((f) => f.name == 'Folder, café')
                .id;
            await harness.searches.replaceOrganization(
              SearchOrganization(
                folders: [
                  for (final folder in firstOrganization.folders)
                    SharedSearchFolder(
                      id: folder.id,
                      name: folder.name,
                      parentId: folder.parentId,
                      position: folder.position,
                      searchIds: [
                        ...folder.searchIds,
                        if (folder.id == firstFolderId) extra.id,
                      ],
                    ),
                ],
                homeSearchIds: firstOrganization.homeSearchIds
                    .where((id) => id != extra.id)
                    .toList(),
              ),
            );
            // Explicit folder copies get a fresh wrapper. Reused searches keep
            // their existing placement, including local-only folder contents.
            await notifier.load(packagePaths['']!);
            state = harness.container.read(importFlowProvider);
            notifier.chooseProfileMapping(
              ProfileSiteKey.fromReference(
                state.profileMappings.single.reference,
              ),
              _localProfileId,
            );
            expect(
              harness.container
                  .read(importFlowProvider)
                  .preflight!
                  .summary
                  .deleted,
              0,
            );
            expect(
              harness.container
                  .read(importFlowProvider)
                  .preflight!
                  .sourceSummaries['pinned_searches']!
                  .entitySummaries['pinned-folder']!
                  .created,
              3,
            );
            await notifier.apply(context);
            state = harness.container.read(importFlowProvider);
            expect(
              state.status,
              ImportFlowStatus.complete,
              reason: state.error is InvalidBackupFormatException
                  ? (state.error! as InvalidBackupFormatException).details
                  : '${state.error}',
            );
            expect(
              await harness.searches.getAll(),
              hasLength(populated ? 7 : 6),
            );
            final copiedOrganization = await harness.searches.getOrganization();
            expect(
              copiedOrganization.folders
                  .singleWhere((folder) => folder.id == firstFolderId)
                  .searchIds,
              [
                ...firstOrganization.folders
                    .singleWhere((f) => f.id == firstFolderId)
                    .searchIds,
                extra.id,
              ],
            );
            expect(
              copiedOrganization.folders.map((folder) => folder.name),
              containsAll([
                'Imported Searches (2)',
                'Folder, café',
                'Second folder',
              ]),
            );
            expect(
              copiedOrganization.folders
                  .singleWhere(
                    (folder) =>
                        folder.parentId ==
                            copiedOrganization.folders
                                .singleWhere(
                                  (f) => f.name == 'Imported Searches (2)',
                                )
                                .id &&
                        folder.name == 'Folder, café',
                  )
                  .searchIds,
              isEmpty,
            );
            expect(
              await harness.bookmarks.getAllBookmarksOrThrow(
                imageUrlResolver: (_) => const DefaultImageUrlResolver(),
              ),
              hasLength(populated ? 3 : 2),
            );
            expect(
              (await harness.groups.getGroups()).map((group) => group.id),
              contains(imported.id),
            );
            if (populated) {
              expect(
                (await harness.searches.getOrganization()).folders
                    .singleWhere((folder) => folder.id == _localFolderId)
                    .id,
                _localFolderId,
              );
            }
            expect(
              (await harness.blacklist.getBlacklist()).map((tag) => tag.name),
              ['local_rule'],
            );
            await notifier.load(packagePaths['']!);
            state = harness.container.read(importFlowProvider);
            final mergedPins = state.resolved!.sources.singleWhere(
              (source) => source.id == 'pinned_searches',
            );
            notifier.replaceSource(
              mergedPins.copyWith(
                items: [
                  for (final item in mergedPins.items)
                    if (item.id.startsWith('folder:'))
                      item.copyWith(
                        action: ImportAction.mergeIntoTarget,
                        targetId: 'folder:$firstFolderId',
                      )
                    else
                      item,
                ],
              ),
            );
            notifier.chooseProfileMapping(
              ProfileSiteKey.fromReference(
                state.profileMappings.single.reference,
              ),
              _localProfileId,
            );
            expect(
              harness.container.read(importFlowProvider).preflight!.isValid,
              true,
            );
            await notifier.apply(context);
            state = harness.container.read(importFlowProvider);
            expect(
              state.status,
              ImportFlowStatus.complete,
              reason: '${state.error}',
            );
            final mergedOrganization = await harness.searches.getOrganization();
            expect(
              mergedOrganization.folders
                  .singleWhere((folder) => folder.id == firstFolderId)
                  .searchIds,
              contains(extra.id),
            );
            expect(
              mergedOrganization.folders
                  .singleWhere((folder) => folder.id == firstFolderId)
                  .searchIds,
              hasLength(3),
            );
            expect(
              await harness.searches.getAll(),
              hasLength(populated ? 7 : 6),
            );
            expect(
              Directory(
                '${harness.directory.path}/import_transactions',
              ).listSync(),
              isEmpty,
            );
          } finally {
            await harness.close();
          }
        });
      },
    );
  }
}

Future<void> _expectSearchOrder(
  _Harness harness, {
  required bool populated,
}) async {
  final searches = await harness.searches.getAll();
  expect(searches, hasLength(populated ? 6 : 5));
  expect(
    searches.map((search) => search.profileId),
    everyElement(_localProfileId),
  );
  final queries = {for (final search in searches) search.id: search.query};
  final organization = await harness.searches.getOrganization();
  expect(organization.folders.map((folder) => folder.name), [
    if (populated) 'Local folder',
    'Imported Searches',
    'Folder, café',
    'Second folder',
  ]);
  final first = organization.folders.singleWhere(
    (folder) => folder.name == 'Folder, café',
  );
  expect(first.searchIds.map((id) => queries[id]), [
    'rating:general order:score',
    'folder_second',
  ]);
  expect(
    organization.folders
        .singleWhere((folder) => folder.name == 'Second folder')
        .searchIds
        .map((id) => queries[id]),
    [
      'side_folder',
    ],
  );
  expect(organization.homeSearchIds, isEmpty);
  expect(
    organization.folders
        .singleWhere((f) => f.name == 'Imported Searches')
        .searchIds
        .map((id) => queries[id]),
    ['home_z', 'home_a'],
  );
}

Future<void> _cli(List<String> arguments) async {
  final result = await Process.run('fvm', [
    'dart',
    'run',
    'bin/boorusama.dart',
    'animeboxes',
    ...arguments,
  ], workingDirectory: 'packages/boorusama_cli');
  expect(result.exitCode, 0, reason: '${result.stderr}');
}

class _Harness {
  _Harness(
    this.directory,
    this.bookmarks,
    this.groups,
    this.searches,
    this.profiles,
    this.blacklist,
    this.container,
    this.boxes,
  );
  final Directory directory;
  final BookmarkHiveRepository bookmarks;
  final BookmarkGroupRepositoryHive groups;
  final HiveSearchSubscriptionRepository searches;
  final HiveBooruConfigRepository profiles;
  final HiveBlacklistedTagRepository blacklist;
  final ProviderContainer container;
  final List<Box> boxes;

  static Future<_Harness> create({required bool populated}) async {
    final directory = await Directory.systemTemp.createTemp(
      'animeboxes_apply_',
    );
    Hive.init(directory.path);
    _registerAdapter(BlacklistedTagHiveObjectAdapter());
    _registerAdapter(BookmarkHiveObjectAdapter());
    _registerAdapter(BookmarkGroupHiveObjectAdapter());
    _registerAdapter(SearchSubscriptionHiveObjectAdapter());
    _registerAdapter(SearchPostPreviewHiveObjectAdapter());
    _registerAdapter(RecentSearchPostHiveObjectAdapter());
    final bookmarkBox = await Hive.openBox<BookmarkHiveObject>('favorites');
    final groupBox = await Hive.openBox<BookmarkGroupHiveObject>(
      'bookmark_groups',
    );
    final searchBox = await Hive.openBox<SearchSubscriptionHiveObject>(
      'pinned_search_subscriptions',
    );
    final organizationBox = await Hive.openBox<dynamic>(
      'pinned_search_folders',
    );
    final profileBox = await Hive.openBox<String>('booru_configs');
    final bookmarks = BookmarkHiveRepository(bookmarkBox);
    final groups = BookmarkGroupRepositoryHive(
      groupBox,
      organizationBox: MemoryBox<dynamic>(),
    );
    final searches = HiveSearchSubscriptionRepository(
      box: searchBox,
      organizationBox: organizationBox,
    );
    final profiles = HiveBooruConfigRepository(box: profileBox);
    final profile = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': _localProfileId,
      'booruId': 20,
      'booruIdHint': 20,
      'url': 'https://danbooru.donmai.us',
      'name': 'Existing account',
    });
    await profiles.addAll([profile]);
    final blacklist = HiveBlacklistedTagRepository();
    await blacklist.init(directory.path);
    await blacklist.addTag('local_rule');
    if (populated) {
      final bookmark = (await bookmarks.addBookmarkWithBookmarks([
        Bookmark.empty.copyWith(
          originalUrl: 'https://local.example/99.jpg',
          sourceUrl: 'https://local.example',
          postId: () => 99,
        ),
      ])).single;
      await groups.createGroup('Local bookmarks', id: _localGroupId);
      await groups.addBookmarks(_localGroupId, {bookmark.id});
      final pin = await searches.create(
        profileId: _localProfileId,
        query: 'local_query',
        name: 'Local',
      );
      await searches.replaceOrganization(
        SearchOrganization(
          folders: [
            SharedSearchFolder(
              id: _localFolderId,
              name: 'Local folder',
              searchIds: [pin.id],
            ),
          ],
          homeSearchIds: const [],
        ),
      );
    }
    final container = ProviderContainer(
      overrides: [
        booruEngineRegistryProvider.overrideWith(_engineRegistry),
        bookmarkRepoProvider.overrideWith((ref) => bookmarks),
        bookmarkGroupRepoProvider.overrideWith((ref) => groups),
        bookmarkUrlResolverProvider.overrideWith(
          (ref, id) => const DefaultImageUrlResolver(),
        ),
        searchSubscriptionRepositoryProvider.overrideWith(
          () => _SearchRepositoryNotifier(searches),
        ),
        booruConfigRepoProvider.overrideWithValue(profiles),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: [profile]),
        ),
        globalBlacklistedTagRepoProvider.overrideWith((ref) => blacklist),
        appFileSystemProvider.overrideWithValue(_FileSystem(directory.path)),
        appVersionProvider.overrideWithValue(null),
        settingsNotifierProvider.overrideWith(
          () => _SettingsNotifier(Settings.defaultSettings),
        ),
      ],
    );
    // Keep the real source catalog loaded before import so empty/local stores
    // use exactly the descriptors shown in the application.
    await container.read(bookmarkProvider.future);
    await container.read(searchSubscriptionsProvider.future);
    container.listen(importFlowProvider, (_, _) {});
    container.read(exportImportSourcesProvider);
    return _Harness(
      directory,
      bookmarks,
      groups,
      searches,
      profiles,
      blacklist,
      container,
      [
        bookmarkBox,
        groupBox,
        searchBox,
        organizationBox,
        profileBox,
        Hive.box<BlacklistedTagHiveObject>('blacklisted_tags'),
      ],
    );
  }

  Future<void> close() async {
    container.dispose();
    // Staged package disposal is asynchronous; Hive handles are owned here.
    for (final box in boxes) {
      await box.close();
    }
    await directory.delete(recursive: true);
  }
}

class _FileSystem extends IoFileSystem {
  const _FileSystem(this.root);
  final String root;
  @override
  Future<String> getAppStoragePath() async => root;
  @override
  Future<String?> getTemporaryPath() async => null;
}

class _SearchRepositoryNotifier extends SearchSubscriptionRepositoryNotifier {
  _SearchRepositoryNotifier(this.repository);
  final SearchSubscriptionRepository repository;
  @override
  Future<SearchSubscriptionRepository> build() async => repository;
}

class _SettingsNotifier extends SettingsNotifier {
  _SettingsNotifier(super.initialSettings);
}

void _registerAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter<T>(adapter);
  }
}

BooruEngineRegistry _engineRegistry(Ref ref) {
  final components = createDanbooru();
  final booru = components.parser.parse();
  return BooruEngineRegistry()..register(
    booru.type,
    BooruEngine(
      booru: booru,
      builder: components.createBuilder(),
      repository: components.createRepository(ref),
    ),
  );
}
