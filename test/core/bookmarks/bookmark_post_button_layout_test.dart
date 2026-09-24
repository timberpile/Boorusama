// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/details_parts/src/toolbars/bookmark_post_button.dart';
import 'package:boorusama/core/posts/post/types.dart';

const _groupId = '550e8400-e29b-41d4-a716-446655440000';

void main() {
  testWidgets(
    'a short group name keeps compact margins around the caption',
    (tester) async {
      final geometry = await _pumpButton(tester, 'Short');

      expect(geometry.caption.top - geometry.glyph.bottom, 2);
      expect(geometry.tapTarget.size, const Size(48, 48));
      expect(geometry.control.height - geometry.tapTarget.height, 3);
      expect(geometry.control.bottom - geometry.caption.bottom, 2);
    },
  );

  testWidgets(
    'a wrapping group name adds only the height of its second line',
    (tester) async {
      final short = await _pumpButton(tester, 'Short');
      final long = await _pumpButton(tester, 'A very long group name');

      final addedTextHeight = long.caption.height - short.caption.height;
      final addedControlHeight = long.control.height - short.control.height;

      expect(addedTextHeight, greaterThan(0));
      expect(addedControlHeight, addedTextHeight);
      expect(long.caption.top - long.glyph.bottom, 2);
      expect(long.control.bottom - long.caption.bottom, 2);
    },
  );

  testWidgets('long pressing the second caption line opens the group picker', (
    tester,
  ) async {
    const groupName = 'A very long group name';
    final geometry = await _pumpButton(tester, groupName);
    final secondLineCenter = Offset(
      geometry.caption.center.dx,
      geometry.caption.bottom - geometry.caption.height / 4,
    );

    await tester.longPressAt(secondLineCenter);
    await tester.pumpAndSettle();

    expect(find.text(groupName), findsNWidgets(2));
  });

  testWidgets('tapping the caption overlap activates the icon button', (
    tester,
  ) async {
    final geometry = await _pumpButton(tester, 'Short');

    await tester.tapAt(
      Offset(
        geometry.caption.center.dx,
        geometry.caption.top + 1,
      ),
    );
    await tester.pump();

    expect(geometry.notifier.toggleCallCount, 1);
  });
}

Future<_ButtonGeometry> _pumpButton(
  WidgetTester tester,
  String groupName,
) async {
  final state = BookmarkLibraryState(
    bookmarks: const [],
    groups: [
      BookmarkGroup(id: _groupId, name: groupName, bookmarkIds: const {}),
    ],
    activeTarget: BookmarkTarget.group(_groupId),
  );
  final post = Bookmark.empty.toPost();
  final config = BooruConfigAuth.fromConfig(BooruConfig.empty);
  final notifier = _FixedBookmarkNotifier(state);

  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(groupName),
      overrides: [
        bookmarkProvider.overrideWith(() => notifier),
      ],
      child: BooruLocalization(
        child: MaterialApp(
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          ),
          home: Align(
            alignment: Alignment.topLeft,
            child: BookmarkPostButton(post: post, config: config),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final glyphFinder = find.byWidgetPredicate(
    (widget) =>
        widget is CustomPaint &&
        widget.painter is BookmarkWithDropdownIconPainter,
  );

  return _ButtonGeometry(
    control: tester.getRect(find.byType(BookmarkPostButton)),
    tapTarget: tester.getRect(find.byType(IconButton)),
    glyph: tester.getRect(glyphFinder),
    caption: tester.getRect(find.text(groupName)),
    notifier: notifier,
  );
}

class _FixedBookmarkNotifier extends BookmarkLibraryNotifier {
  _FixedBookmarkNotifier(this.value);

  final BookmarkLibraryState value;
  final _toggleCompleter = Completer<BookmarkToggleOutcome>();
  var toggleCallCount = 0;

  @override
  FutureOr<BookmarkLibraryState> build() => value;

  @override
  Future<BookmarkToggleOutcome> togglePostTarget(
    BooruConfigAuth config,
    Post post, {
    BookmarkTarget? target,
    bool activateTarget = false,
  }) {
    toggleCallCount++;
    return _toggleCompleter.future;
  }
}

class _ButtonGeometry {
  const _ButtonGeometry({
    required this.control,
    required this.tapTarget,
    required this.glyph,
    required this.caption,
    required this.notifier,
  });

  final Rect control;
  final Rect tapTarget;
  final Rect glyph;
  final Rect caption;
  final _FixedBookmarkNotifier notifier;
}
