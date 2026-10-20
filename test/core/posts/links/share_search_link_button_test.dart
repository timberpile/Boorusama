import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/links/boorusama_link_file.dart';
import 'package:boorusama/core/posts/links/boorusama_search_link.dart';
import 'package:boorusama/core/posts/links/share_search_link_button.dart';
import 'package:boorusama/core/posts/shares/src/share_action_adapter.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:share_plus/share_plus.dart';

import '../../../support/fakes/memory_app_file_system.dart';
import 'boorusama_post_link_test.dart' show config;

Future<void> _pump(
  WidgetTester tester, {
  required BoorusamaSearchLink? link,
  required MemoryAppFileSystem fs,
  required ShareActionAdapter adapter,
  String profileName = 'My Booru',
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [appFileSystemProvider.overrideWithValue(fs)],
    child: MaterialApp(
      theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
      builder: (context, child) => KurumiTheme(
        data: KurumiThemeData.fromMaterial(Theme.of(context)),
        child: OKToast(child: TranslationProvider(child: child!)),
      ),
      home: Scaffold(
        body: Center(
          child: SearchLinkShareMenu(
            link: link,
            profileName: profileName,
            shareAdapter: adapter,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  final search = BoorusamaSearchLink.fromTags(
    auth: config('https://site.test').auth,
    tags: ['one_piece', '-rating:safe'],
  )!;

  testWidgets('Share search sends one document with readable query text', (
    tester,
  ) async {
    final fs = MemoryAppFileSystem();
    var calls = 0;
    await _pump(
      tester,
      link: search,
      fs: fs,
      adapter: ShareActionAdapter((params) async {
        calls++;
        expect(params.files, hasLength(1));
        expect(params.uri, isNull);
        expect(params.text, "Search 'one_piece -rating:safe' on My Booru");
        expect(params.sharePositionOrigin!.width, greaterThan(0));
        final file = params.files!.single;
        expect(file.mimeType, BoorusamaLinkFile.mimeType);
        expect(
          BoorusamaLinkFile.decode(await fs.readBytes(file.path)).uri,
          search.uri,
        );
        return const ShareResult('', ShareResultStatus.success);
      }),
    );
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    await tester.tap(find.byTooltip('Boorusama Link File'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Copy Boorusama search link'), findsNothing);
    expect(find.text('Share Boorusama search link'), findsNothing);
    expect(find.byType(PopupMenuButton), findsNothing);
  });

  testWidgets(
    'disabled search and pending handoff cannot dispatch extra shares',
    (tester) async {
      final pending = Completer<ShareResult>();
      var calls = 0;
      final adapter = ShareActionAdapter((params) {
        calls++;
        return pending.future;
      });
      final fs = MemoryAppFileSystem();
      await _pump(tester, link: null, fs: fs, adapter: adapter);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      await _pump(tester, link: search, fs: fs, adapter: adapter);
      await tester.tap(find.byTooltip('Boorusama Link File'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      pending.complete(const ShareResult('', ShareResultStatus.success));
      await tester.pumpAndSettle();
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNotNull,
      );
    },
  );
}
