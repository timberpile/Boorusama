import 'package:boorusama/core/navigation/profile_context_menu.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets(
      'profile popup keyboard selection with twelve profiles at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        String? selected;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 300),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomRight,
                  child: ProfileContextMenuButton(
                    entries: [
                      for (var i = 0; i < 12; i++)
                        ProfileMenuEntry(
                          id: '$i',
                          caption: 'Profile number $i',
                          url: 'https://danbooru.donmai.us',
                        ),
                    ],
                    selectedProfileId: '0',
                    tooltip: 'Profiles',
                    onSelected: (id) => selected = id,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Profiles'));
        await tester.pumpAndSettle();
        final menu = tester.getRect(find.byType(SingleChildScrollView));
        expect(menu.left, greaterThanOrEqualTo(12));
        expect(menu.right, lessThanOrEqualTo(width - 12));
        expect(menu.top, greaterThanOrEqualTo(12));
        expect(menu.bottom, lessThanOrEqualTo(488));
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(selected, '11');
        expect(find.text('Profile number 11'), findsNothing);
        final trigger = tester.widget<IconButton>(find.byType(IconButton));
        expect(trigger.focusNode!.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(trigger.focusNode!.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
