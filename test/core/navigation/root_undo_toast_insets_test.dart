import '../../support/keyboard_toast_host.dart';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/navigation/app_navigation.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/navigation/navigation_overlay_insets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  for (final withShell in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'root removal feedback follows actual insets with shell=$withShell scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          tester.view.viewPadding = const FakeViewPadding(bottom: 24);
          tester.view.padding = const FakeViewPadding(bottom: 24);
          addTearDown(tester.view.reset);
          addTearDown(dismissAllToast);
          final container = ProviderContainer(
            overrides: [bookmarkProvider.overrideWith(_EmptyBookmarks.new)],
          );
          addTearDown(container.dispose);
          final navigation = container.read(appNavigationProvider);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: BooruLocalization(
                child: MaterialApp(
                  navigatorKey: navigation.navigatorKey,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: KeyboardToastHost(
                      enabled: !withShell,
                      child: child!,
                    ),
                  ),
                  home: Builder(
                    builder: (context) {
                      final system = MediaQuery.of(context);
                      final page = Scaffold(
                        body: Builder(
                          builder: (context) => TextButton(
                            onPressed: () {
                              final root = Navigator.of(
                                context,
                                rootNavigator: true,
                              ).context;
                              expect(
                                KurumiOverlayInsetsScope.maybeOf(root),
                                isNull,
                              );
                              container
                                  .read(bookmarkProvider.notifier)
                                  .showRemovalUndo(
                                    root,
                                    const BookmarkGroupRemovalResult(
                                      removedCount: 1,
                                    ),
                                  );
                            },
                            child: const Text('Remove'),
                          ),
                        ),
                      );
                      return withShell
                          ? NavigationOverlayInsetsScope(
                              systemMediaQuery: system,
                              extent: 88,
                              child: MediaQuery(
                                data: system.copyWith(
                                  padding: const EdgeInsets.only(bottom: 88),
                                ),
                                child: page,
                              ),
                            )
                          : page;
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Remove'));
          final toast = find.byKey(const ValueKey('kurumi-action-toast'));
          for (var frame = 0; frame < 30 && toast.evaluate().isEmpty; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          await tester.pumpAndSettle();
          expect(toast, findsOneWidget);
          expect(
            tester.getRect(toast).bottom,
            closeTo(640 - (withShell ? 88 : 24) - 16, 0.5),
          );

          final chrome = container.read(navigationChromeProvider.notifier);
          chrome.userScroll(
            delta: 88,
            pixels: 100,
            outOfRange: false,
            extent: 88,
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(toast).bottom, closeTo(640 - 24 - 16, 0.5));
          chrome.show();
          await tester.pumpAndSettle();
          expect(
            tester.getRect(toast).bottom,
            closeTo(640 - (withShell ? 88 : 24) - 16, 0.5),
          );

          if (withShell) {
            final selection = Object();
            chrome.setSelectionFor(
              selection,
              true,
              bottomObstruction: 150,
            );
            await tester.pumpAndSettle();
            expect(tester.getRect(toast).bottom, closeTo(640 - 150 - 16, 0.5));
            chrome.setSelectionFor(
              selection,
              true,
              bottomObstruction: 220,
            );
            await tester.pumpAndSettle();
            expect(tester.getRect(toast).bottom, closeTo(640 - 220 - 16, 0.5));
            chrome.setSelectionFor(selection, false);
            await tester.pumpAndSettle();
            expect(tester.getRect(toast).bottom, closeTo(640 - 88 - 16, 0.5));

            final viewer = Object();
            chrome.setViewerFor(
              viewer,
              active: true,
              immersive: false,
              bottomObstruction: 80,
            );
            await tester.pumpAndSettle();
            expect(tester.getRect(toast).bottom, closeTo(640 - 80 - 16, 0.5));
            chrome.setViewerFor(
              viewer,
              active: true,
              immersive: true,
              bottomObstruction: 0,
            );
            await tester.pumpAndSettle();
            expect(tester.getRect(toast).bottom, closeTo(640 - 24 - 16, 0.5));
            chrome.setViewerFor(viewer, active: false, immersive: false);
            await tester.pumpAndSettle();
          }

          tester.view.viewInsets = const FakeViewPadding(bottom: 240);
          tester.view.padding = const FakeViewPadding();
          await tester.pumpAndSettle();
          expect(tester.getRect(toast).bottom, closeTo(640 - 240 - 16, 0.5));
          if (withShell) {
            final selection = Object();
            chrome.setSelectionFor(
              selection,
              true,
              bottomObstruction: 120,
            );
            await tester.pumpAndSettle();
            expect(
              tester.getRect(toast).bottom,
              closeTo(640 - 240 - 120 - 16, 0.5),
            );
            chrome.setSelectionFor(selection, false);
            await tester.pumpAndSettle();
            expect(tester.getRect(toast).bottom, closeTo(640 - 240 - 16, 0.5));
          }
          expect(find.text('Undo').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);

          dismissAllToast();
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 5));
          expect(navigation.feedbackKey.currentContext, isNull);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

// Presentation-only setup: exercise the real showRemovalUndo implementation
// without starting disk-backed repositories. Undo mutation tests live elsewhere.
class _EmptyBookmarks extends BookmarkLibraryNotifier {
  @override
  BookmarkLibraryState build() =>
      BookmarkLibraryState(bookmarks: [], groups: []);
}
