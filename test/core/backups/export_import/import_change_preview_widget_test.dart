import 'package:boorusama/core/backups/export_import/import/import_change_preview.dart';
import 'package:boorusama/core/backups/export_import/widgets/import_change_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;

void main() {
  testWidgets('expanded field details fit 280px at doubled text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const oldUrl =
        'https://example.invalid/collections/landscapes/old?sort=oldest';
    const newUrl =
        'https://example.invalid/collections/landscapes/very-long-new-path?sort=newest';
    final details = importFieldChanges(
      {
        'endpoint': oldUrl,
        'connection': {
          'headers': {'Authorization': 'old-private-header'},
          'credentials': {'password': 'old-private-password'},
        },
      },
      {
        'endpoint': newUrl,
        'connection': {
          'headers': {'Authorization': 'new-private-header'},
          'credentials': {'password': 'new-private-password'},
        },
      },
    );
    final endpoint = details.singleWhere((detail) => detail.key == 'endpoint');
    expect(endpoint.before, startsWith(oldUrl));
    expect(endpoint.after, startsWith(newUrl));
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(280, 1400),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ImportChangePreview(
                  rows: [
                    ImportChangePreviewRow(
                      category: 'profiles',
                      id: 'profile',
                      kind: ImportChangeKind.changed,
                      label: 'Personal connection',
                      details: details,
                    ),
                  ],
                  sourceNames: const {'profiles': 'Profiles'},
                  profileNames: const {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Planned changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Personal connection'));
    await tester.tap(find.text('Personal connection'));
    await tester.pumpAndSettle();
    expect(find.text('endpoint'), findsOneWidget);
    expect(
      find.text('~ ${endpoint.before} → ${endpoint.after}'),
      findsOneWidget,
    );
    expect(find.text('connection.headers.Authorization'), findsOneWidget);
    expect(find.text('connection.credentials.password'), findsOneWidget);
    expect(find.text('~ •••••• → ••••••'), findsNWidgets(2));
    for (final secret in [
      'old-private-header',
      'new-private-header',
      'old-private-password',
      'new-private-password',
    ]) {
      expect(find.textContaining(secret), findsNothing);
    }
    await tester.ensureVisible(
      find.text('connection.credentials.password'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('feed details show profile names and readable query changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ImportChangePreview(
                rows: [
                  ImportChangePreviewRow(
                    category: 'following_feeds',
                    id: 'feed',
                    kind: ImportChangeKind.changed,
                    isContainer: true,
                    children: [
                      ImportChangePreviewRow(
                        category: 'feed_queries',
                        id: 'old',
                        kind: ImportChangeKind.removed,
                        label: 'old artist',
                        profileId: 'old-id',
                      ),
                      ImportChangePreviewRow(
                        category: 'feed_queries',
                        id: 'new',
                        kind: ImportChangeKind.added,
                        label: 'new artist',
                        profileId: 'new-id',
                      ),
                    ],
                    label: 'Favorite artists',
                    previousLabel: 'Artist watch',
                    profileId: 'new-id',
                    details: [
                      ...importFieldChanges(
                        {'profileId': 'old-id', 'position': 0},
                        {'profileId': 'new-id', 'position': 2},
                      ),
                    ],
                  ),
                ],
                sourceNames: const {'following_feeds': 'Following feeds'},
                profileNames: const {'old-id': 'Personal', 'new-id': 'Work'},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Planned changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Following feeds'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artist watch → Favorite artists'));
    await tester.pumpAndSettle();
    expect(find.text('3 changes'), findsNWidgets(3));
    expect(find.text('~ Personal → Work'), findsOneWidget);
    expect(find.text('~ 1 → 3'), findsOneWidget);
    expect(find.text('old artist'), findsOneWidget);
    expect(find.text('new artist'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Work'), findsNWidgets(2));
    expect(find.text('−'), findsOneWidget);
    expect(find.text('+'), findsOneWidget);
    expect(find.textContaining('old-id'), findsNothing);
    expect(find.textContaining('new-id'), findsNothing);
    expect(find.textContaining('queries['), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'new feed and search entry totals remain visible while collapsed',
    (tester) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: ImportChangePreview(
                rows: [
                  for (final count in [1, 2])
                    ImportChangePreviewRow(
                      category: 'following_feeds',
                      id: 'feed-$count',
                      kind: ImportChangeKind.added,
                      label: 'Feed $count',
                      isContainer: true,
                      children: [
                        for (var index = 0; index < count; index++)
                          ImportChangePreviewRow(
                            category: 'feed_queries',
                            id: '$index',
                            kind: ImportChangeKind.added,
                            label: 'Query $count-$index',
                          ),
                      ],
                    ),
                ],
                sourceNames: const {'following_feeds': 'Following feeds'},
                profileNames: const {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('5 changes'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      await tester.tap(find.text('Planned changes'));
      await tester.pumpAndSettle();
      expect(find.text('5 changes'), findsNWidgets(2));
      await tester.tap(find.text('Following feeds'));
      await tester.pumpAndSettle();
      expect(find.text('2 changes'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('3 changes'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
      expect(find.textContaining('Query'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home shows only its search count and a neutral container icon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ImportChangePreview(
                rows: [
                  ImportChangePreviewRow(
                    category: 'pinned_folders',
                    id: 'home',
                    kind: ImportChangeKind.changed,
                    label: '__home',
                    isContainer: true,
                    entityChanged: false,
                    children: [
                      ImportChangePreviewRow(
                        category: 'pinned_searches',
                        id: 'pin',
                        kind: ImportChangeKind.added,
                        label: 'cat',
                      ),
                    ],
                  ),
                ],
                sourceNames: const {'pinned_searches': 'Pinned searches'},
                profileNames: const {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('1 change'), findsOneWidget);
    await tester.tap(find.text('Planned changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pinned searches'));
    await tester.pumpAndSettle();
    expect(find.text('1 change'), findsNWidgets(3));
    expect(find.text('+1'), findsNWidgets(3));
    expect(find.text('~0'), findsNWidgets(3));
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.text('~'), findsNothing);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('cat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'collapsed totals and independent categories fit 280px at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(280, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(280, 1400),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: ImportChangePreview(
                      rows: [
                        ImportChangePreviewRow(
                          category: 'bookmarks',
                          id: 'group',
                          kind: ImportChangeKind.changed,
                          label: 'Long bookmark collection title',
                          membershipsAdded: 12,
                          membershipsRemoved: 4,
                          entityChanged: false,
                        ),
                        ImportChangePreviewRow(
                          category: 'pinned_folders',
                          id: 'folder',
                          kind: ImportChangeKind.changed,
                          label: 'Inspiration',
                          entityChanged: false,
                          isContainer: true,
                          children: [
                            ImportChangePreviewRow(
                              category: 'pinned_searches',
                              id: 'pin',
                              kind: ImportChangeKind.added,
                              label: 'scenery sky',
                              profileId: 'profile',
                            ),
                          ],
                        ),
                      ],
                      sourceNames: const {
                        'bookmarks': 'Bookmark groups',
                        'pinned_searches': 'Pinned searches',
                      },
                      profileNames: const {'profile': 'Personal'},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('17 changes'), findsOneWidget);
        expect(find.text('+13'), findsOneWidget);
        expect(find.text('−4'), findsOneWidget);
        expect(find.text('Long bookmark collection title'), findsNothing);
        await tester.tap(find.text('Planned changes'));
        await tester.pumpAndSettle();
        expect(find.text('16 changes'), findsOneWidget);
        expect(find.text('1 change'), findsOneWidget);
        await tester.tap(
          find.text('Bookmark groups'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Long bookmark collection title'), findsOneWidget);
        expect(find.text('scenery sky'), findsNothing);
        await tester.ensureVisible(
          find.text('Pinned searches'),
        );
        await tester.tap(
          find.text('Pinned searches'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Long bookmark collection title'), findsOneWidget);
        expect(find.text('scenery sky'), findsNothing);
        expect(find.text('Personal'), findsNothing);
        expect(find.text('Pinned searches'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('change-category-pinned_folders')),
          findsNothing,
        );
        expect(find.textContaining('Unchanged and skipped'), findsNothing);
        await tester.ensureVisible(find.text('Inspiration'));
        await tester.tap(find.text('Inspiration'));
        await tester.pumpAndSettle();
        expect(find.text('Folder'), findsOneWidget);
        expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
        expect(find.text('scenery sky'), findsOneWidget);
        expect(find.text('Personal'), findsOneWidget);
        expect(find.text('+'), findsOneWidget);
        expect(find.textContaining('∅'), findsNothing);

        await tester.ensureVisible(
          find.text('Bookmark groups'),
        );
        await tester.tap(
          find.text('Bookmark groups'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Long bookmark collection title'), findsNothing);
        expect(find.text('scenery sky'), findsOneWidget);
        await tester.ensureVisible(
          find.text('Planned changes'),
        );
        await tester.tap(find.text('Planned changes'));
        await tester.pumpAndSettle();
        expect(find.text('17 changes'), findsOneWidget);
        expect(find.text('scenery sky'), findsNothing);
        await tester.tap(find.text('Planned changes'));
        await tester.pumpAndSettle();
        expect(find.text('scenery sky'), findsOneWidget);
        expect(find.text('Long bookmark collection title'), findsNothing);
        await tester.ensureVisible(find.text('Inspiration'));
        await tester.tap(find.text('Inspiration'));
        await tester.pumpAndSettle();
        expect(find.text('scenery sky'), findsNothing);
        expect(find.text('1 change'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
