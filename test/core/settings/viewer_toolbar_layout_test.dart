import 'dart:convert';
import 'dart:math';

import 'package:boorusama/core/settings/src/types/viewer_toolbar_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final all = ViewerToolbarAction.values.toSet();

  test('missing, malformed and future schemas preserve legacy defaults', () {
    for (final value in [
      null,
      true,
      [],
      {},
      {'version': 2, 'toolbar': [], 'more': []},
      {'version': 1, 'toolbar': 'bookmark', 'more': []},
    ]) {
      expect(ViewerToolbarLayout.tryParse(value), isNull);
    }
  });

  test('normalization removes duplicates and retains all known actions', () {
    final layout = ViewerToolbarLayout.tryParse({
      'version': 1,
      'toolbar': ['bookmark', 'bookmark', 'favorite', 'future-action', null],
      'more': ['favorite', 'share', 'share', 42],
    })!;
    expect(layout.toolbar, [
      ViewerToolbarAction.bookmark,
      ViewerToolbarAction.favorite,
    ]);
    expect(layout.more.first, ViewerToolbarAction.share);
    expect({...layout.toolbar, ...layout.more}, all);
    expect(layout.toolbar.length + layout.more.length, all.length);
  });

  test('overflow-only customization is different from no customization', () {
    final layout = ViewerToolbarLayout.tryParse({
      'version': 1,
      'toolbar': [],
      'more': ['share', 'bookmark'],
    })!;
    expect(layout.toolbar, isEmpty);
    expect(layout.more.take(2), [
      ViewerToolbarAction.share,
      ViewerToolbarAction.bookmark,
    ]);
    expect(layout.project(all, capacity: 5).toolbar, isEmpty);
  });

  test('extra stored toolbar entries remain available in More', () {
    final layout = ViewerToolbarLayout(toolbar: ViewerToolbarAction.values);
    expect(layout.toolbar.length, ViewerToolbarLayout.maxToolbarActions);
    expect({...layout.toolbar, ...layout.more}, all);
    expect(layout.more.first, ViewerToolbarAction.values[5]);
  });

  test('custom order survives JSON round trip and unrelated mutations', () {
    final layout = ViewerToolbarLayout(
      toolbar: const [ViewerToolbarAction.share, ViewerToolbarAction.bookmark],
      more: const [ViewerToolbarAction.tags, ViewerToolbarAction.download],
    );
    expect(
      ViewerToolbarLayout.tryParse(jsonDecode(jsonEncode(layout.toJson()))),
      layout,
    );
    expect(() => layout.toolbar.clear(), throwsUnsupportedError);
    expect(() => layout.more.clear(), throwsUnsupportedError);
  });

  test(
    'compact projection protects the middle and removes left first on ties',
    () {
      final layout = ViewerToolbarLayout.editorDefault();
      final four = layout.project(all, capacity: 4);
      expect(four.toolbar, layout.toolbar.skip(1));
      final three = layout.project(all, capacity: 3);
      expect(three.toolbar, layout.toolbar.sublist(1, 4));
      expect(three.more.take(2), [layout.toolbar.first, layout.toolbar.last]);
      expect(layout.project(all, capacity: 1).toolbar, [layout.toolbar[2]]);
      expect(layout.project(all, capacity: 0).toolbar, isEmpty);
      expect(layout.project(all, capacity: 99).toolbar, layout.toolbar);
    },
  );

  test('profile capabilities filter presentation, never stored positions', () {
    final layout = ViewerToolbarLayout(
      toolbar: const [
        ViewerToolbarAction.upvote,
        ViewerToolbarAction.bookmark,
        ViewerToolbarAction.favorite,
      ],
    );
    final before = jsonEncode(layout.toJson());
    final guest = layout.project({ViewerToolbarAction.bookmark}, capacity: 5);
    expect(guest.toolbar, [ViewerToolbarAction.bookmark]);
    expect(guest.more, isEmpty);
    expect(jsonEncode(layout.toJson()), before);
    expect(layout.project(all, capacity: 5).toolbar, layout.toolbar);
  });

  test('moving within and between sections uses insertion coordinates', () {
    final layout = ViewerToolbarLayout.editorDefault();
    final first = layout.toolbar.first;
    final moved = layout.move(first, toToolbar: true, index: 5);
    expect(moved.toolbar.last, first);
    expect(moved.toolbar.take(4), layout.toolbar.skip(1));
    final inMore = moved.move(first, toToolbar: false, index: 0);
    expect(inMore.more.first, first);
    expect(inMore.toolbar.length, 4);
    expect(inMore.move(first, toToolbar: true, index: 2).toolbar[2], first);
  });

  test(
    'full toolbar requires an explicit replacement, not silent eviction',
    () {
      final layout = ViewerToolbarLayout.editorDefault();
      final incoming = layout.more.first;
      expect(layout.move(incoming, toToolbar: true, index: 0), layout);
      final displaced = layout.toolbar[2];
      final replaced = layout.replace(displaced, withAction: incoming);
      expect(replaced.toolbar[2], incoming);
      expect(replaced.more.first, displaced);
      expect({...replaced.toolbar, ...replaced.more}, all);
    },
  );

  test('projection never loses or duplicates any available action', () {
    final random = Random(112);
    for (var i = 0; i < 250; i++) {
      final actions = [...ViewerToolbarAction.values]..shuffle(random);
      final count = random.nextInt(6);
      final layout = ViewerToolbarLayout(
        toolbar: actions.take(count),
        more: actions.skip(count),
      );
      final available = all.where((_) => random.nextBool()).toSet();
      for (var capacity = 0; capacity <= 6; capacity++) {
        final projected = layout.project(available, capacity: capacity);
        final output = [...projected.toolbar, ...projected.more];
        expect(output.toSet(), available);
        expect(output.length, available.length);
        expect(projected.toolbar.length, lessThanOrEqualTo(capacity));
      }
    }
  });
  test('capacity reserves More and remains bounded at narrow widths', () {
    expect(viewerToolbarCapacity(0), 0);
    expect(viewerToolbarCapacity(48), 0);
    expect(viewerToolbarCapacity(296), 4);
    expect(viewerToolbarCapacity(366), 5);
    expect(viewerToolbarCapacity(2000), 5);
  });
}
