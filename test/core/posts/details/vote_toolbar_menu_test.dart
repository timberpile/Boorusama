import 'package:boorusama/core/posts/details_parts/src/toolbars/customizable_post_toolbar.dart';
import 'package:boorusama/core/posts/votes/types.dart';
import 'package:boorusama/core/posts/votes/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/themes/colors/src/colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  for (final upvote in [true, false]) {
    for (final active in [true, false]) {
      for (final removable in [true, false]) {
        testWidgets(
          'vote menu up=$upvote active=$active removable=$removable',
          (tester) async {
            var added = 0;
            var removed = 0;
            final vote = active
                ? (upvote ? VoteState.upvoted : VoteState.downvoted)
                : VoteState.unvote;
            final semantics = tester.ensureSemantics();
            await tester.pumpWidget(
              ProviderScope(
                child: BooruLocalization(
                  child: MaterialApp(
                    theme: ThemeData().withBoorusamaColors(),
                    builder: (context, child) => KurumiTheme(
                      data: KurumiThemeData.fromMaterial(Theme.of(context)),
                      child: child!,
                    ),
                    home: Scaffold(
                      body: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConfiguredPostToolbar(
                          layout: ViewerToolbarLayout(toolbar: const []),
                          buttons: [
                            ViewerToolbarButtonData(
                              action: upvote
                                  ? ViewerToolbarAction.upvote
                                  : ViewerToolbarAction.downvote,
                              title: 'Vote',
                              widget: const SizedBox.shrink(),
                              menuBuilder: (_, _) => upvote
                                  ? UpvotePostButton(
                                      voteState: vote,
                                      onUpvote: () => added++,
                                      onRemoveUpvote: removable
                                          ? () => removed++
                                          : null,
                                      menuItem: true,
                                    )
                                  : DownvotePostButton(
                                      voteState: vote,
                                      onDownvote: () => added++,
                                      onRemoveDownvote: removable
                                          ? () => removed++
                                          : null,
                                      menuItem: true,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.byKey(const Key('viewer-toolbar-more')));
            await tester.pumpAndSettle();
            final row = find.byType(KurumiPopupMenuItem);
            expect(
              tester.widget<KurumiPopupMenuItem>(row).onTap == null,
              active && !removable,
            );
            final icon = tester.widget<Icon>(
              find.descendant(of: row, matching: find.byType(Icon)),
            );
            expect(icon.color != null, active);
            expect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.toggled == active,
              ),
              findsWidgets,
            );
            if (!active || removable) {
              await tester.tap(row);
              await tester.pumpAndSettle();
              expect(added, active ? 0 : 1);
              expect(removed, active ? 1 : 0);
              expect(find.byType(KurumiPopupMenuItem), findsNothing);
            }
            semantics.dispose();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
