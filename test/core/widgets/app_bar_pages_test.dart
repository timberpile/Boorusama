import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/create/src/pages/create_booru_config_scaffold.dart';
import 'package:boorusama/core/settings/src/widgets/settings_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final configuration in [false, true]) {
      testWidgets(
        '${configuration ? 'source configuration' : 'settings'} title fits at ${scale}x',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final title = configuration
              ? '${'long-source-' * 12}example.test'
              : 'A long translated settings page title with many words';
          await tester.pumpWidget(
            ProviderScope(
              child: BooruLocalization(
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: KurumiTheme(
                      data: KurumiThemeData.fromMaterial(Theme.of(context)),
                      child: child!,
                    ),
                  ),
                  home: configuration
                      ? Scaffold(
                          appBar: KurumiAppBar(
                            leading: BackButton(onPressed: () {}),
                            titleSpacing: 0,
                            title: SelectedBooruChip(
                              booruType: BooruType.hydrus,
                              url: 'https://$title',
                            ),
                            actions: [
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.save),
                              ),
                            ],
                          ),
                          body: const SizedBox(key: ValueKey('content')),
                        )
                      : SettingsPageScaffold(
                          title: Text(title),
                          children: const [],
                        ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final text = tester.widget<Text>(find.text(title));
          expect(text.style!.fontSize, inInclusiveRange(12, 22));
          expect(text.textScaler!.scale(12), 12 * scale);
          final rect = tester.getRect(find.text(title));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(56));
          if (configuration) {
            final subtitle = find.textContaining('Hydrus', findRichText: true);
            expect(subtitle, findsOneWidget);
            expect(tester.getRect(subtitle).bottom, lessThanOrEqualTo(56));
            expect(rect.overlaps(tester.getRect(subtitle)), isFalse);
            expect(
              rect.right,
              lessThanOrEqualTo(
                tester
                    .getRect(find.widgetWithIcon(IconButton, Icons.save))
                    .left,
              ),
            );
            expect(
              tester.getTopLeft(find.byKey(const ValueKey('content'))).dy,
              56,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
