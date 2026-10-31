import 'package:boorusama/core/posts/links/boorusama_search_link.dart';
import 'package:boorusama/core/posts/links/share_search_link_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final valid in [true, false]) {
    testWidgets(
      'search file sharing keeps the standard Share icon with enabled=$valid',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final link = BoorusamaSearchLink.parse(
            Uri(
              scheme: 'boorusama',
              host: 'search',
              path: '/open',
              queryParameters: {
                'v': '1',
                'engine': 'danbooru',
                'site': 'https://danbooru.donmai.us/',
                'mode': 'raw',
                'q': 'cat',
              },
            ).toString(),
          );
          await tester.pumpWidget(
            ProviderScope(
              child: BooruLocalization(
                child: MaterialApp(
                  home: Scaffold(
                    body: SearchLinkShareMenu(link: valid ? link : null),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final button = tester.widget<IconButton>(find.byType(IconButton));
          expect(button.tooltip, isNotEmpty);
          expect(button.onPressed != null, valid);
          expect(find.byIcon(Icons.share), findsOneWidget);
          expect(find.byType(Image), findsNothing);
          expect(
            tester.getSize(find.byType(IconButton)).shortestSide,
            greaterThanOrEqualTo(48),
          );
          // Flutter exposes a button tooltip through the dedicated semantics
          // tooltip field rather than merging it into the label.
          expect(
            tester
                .getSemantics(find.byType(IconButton))
                .getSemanticsData()
                .tooltip,
            'Boorusama Link File',
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
