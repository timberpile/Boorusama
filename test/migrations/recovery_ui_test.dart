import 'package:boorusama/boorus/sankaku/sankaku_repository.dart';
import 'package:boorusama/boorus/danbooru/danbooru_repository.dart';
import 'package:boorusama/core/backups/widgets/import_booru_configs_alert_dialog.dart';
import 'package:boorusama/core/backups/sources/booru_configs_source.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/downloads/sidecar/data.dart';
import 'package:boorusama/core/downloads/sidecar/providers.dart';
import 'package:boorusama/core/downloads/sidecar/types.dart';
import 'package:boorusama/core/downloads/sidecar/widgets.dart';
import 'package:boorusama/core/search/search/src/types/search_option.dart';
import 'package:boorusama/core/search/search/src/widgets/shared_search_options_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../support/fakes/memory_app_file_system.dart';

Widget _app(Widget child, {double keyboard = 0}) => TranslationProvider(
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(2),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: KurumiTheme(
        data: KurumiThemeData.fromMaterial(Theme.of(context)),
        child: child!,
      ),
    ),
    home: child,
  ),
);

void main() {
  testWidgets(
    'metadata failures remain visible and retry changes only metadata',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fs = MemoryAppFileSystem();
      final store = SidecarStore(directory: '/memory/intents', fs: fs);
      const media = '/memory/downloads/image.jpg';
      await store.prepare(
        'failed',
        media,
        SidecarSnapshot(
          format: SidecarFormat.tags,
          tags: const ['tag'],
          quality: 'original',
        ),
      );
      await fs.writeString(media, 'saved media');
      await fs.writeString('$media.txt', 'conflicting metadata');
      await expectLater(store.complete('failed', media), throwsStateError);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sidecarStoreProvider.overrideWith((ref) async => store)],
          child: _app(const Scaffold(body: SidecarFailureNotice())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Metadata needs attention'), findsOneWidget);
      await tester.tap(find.byType(SidecarFailureNotice));
      await tester.pumpAndSettle();
      expect(find.text('image.jpg'), findsOneWidget);
      await tester.tap(find.byTooltip('Retry'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Check the folder permissions'),
        findsOneWidget,
      );
      expect(await fs.readString(media), 'saved media');
      expect(await fs.readString('$media.txt'), 'conflicting metadata');
      await fs.deleteFile('$media.txt');
      await tester.scrollUntilVisible(find.byTooltip('Retry'), 150);
      await tester.tap(find.byTooltip('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('image.jpg'), findsNothing);
      expect(await store.failures(), isEmpty);
      expect(await fs.readString(media), 'saved media');
      expect(await fs.readString('$media.txt'), 'tag\n');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shared options fit with large text and keyboard and submit a typed query',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => selected = await showDialog<String>(
                  context: context,
                  builder: (_) => const SearchOptionDialog(
                    option: SearchOption(
                      kind: SearchOptionKind.user,
                      prefix: 'user',
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
          keyboard: 220,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'sample_user');
      await tester.pump();
      await tester.ensureVisible(find.text('Add'));
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(selected, 'user:sample_user');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile import warns about optional fallbacks at narrow width and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profile = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': '00000000-0000-4000-8000-000000000003',
        'name': 'Preserved',
        'thumbnailActions': const ['future'],
        'network': const {'mediaHostOverridesEnabled': 'invalid'},
      });
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ImportBooruConfigsAlertDialog(
                    data: BooruConfigExportData(
                      data: [profile],
                      exportData: const ExportDataPayload.legacy(data: []),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('unsupported thumbnail actions'),
        findsOneWidget,
      );
      expect(find.textContaining('invalid media host switch'), findsOneWidget);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test('shared capability keeps source-specific rating labels', () {
    final definitions = Provider(
      (ref) => (
        SankakuRepository(ref: ref).searchOptions,
        DanbooruRepository(ref: ref).searchOptions,
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final (sankaku, danbooru) = container.read(definitions);
    final sankakuRating = sankaku.firstWhere(
      (option) => option.kind == SearchOptionKind.rating,
    );
    final danbooruRating = danbooru.firstWhere(
      (option) => option.kind == SearchOptionKind.rating,
    );
    expect(sankakuRating.valueLabels['s'], SearchOptionValueLabel.safe);
    expect(sankakuRating.compose('g'), isNull);
    expect(danbooruRating.valueLabels['s'], SearchOptionValueLabel.sensitive);
    expect(danbooruRating.compose('g'), 'rating:g');
  });

  test('site option mappings reject unknown/empty values', () {
    const rating = SearchOption(
      kind: SearchOptionKind.rating,
      prefix: 'rating',
      values: ['s', 'q', 'e'],
    );
    expect(rating.compose('q'), 'rating:q');
    expect(rating.compose('unknown'), isNull);
    expect(rating.compose(''), isNull);
    const favorite = SearchOption(
      kind: SearchOptionKind.favorites,
      prefix: 'fav',
    );
    expect(favorite.compose('sample user'), 'fav:sample_user');
    expect(favorite.compose('fav:sample'), isNull);
  });
}
