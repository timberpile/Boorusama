import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/bookmarks/src/data/bookmark_view_refresh_gate.dart';

void main() {
  test('bookmark changes refresh immediately while the viewer is closed', () {
    final gate = BookmarkViewRefreshGate();

    expect(gate.onLibraryChanged(), isTrue);
  });

  test('bookmark changes refresh once after the viewer closes', () {
    final gate = BookmarkViewRefreshGate();

    expect(gate.onDetailsVisibilityChanged(true), isFalse);
    expect(gate.onLibraryChanged(), isFalse);
    expect(gate.onLibraryChanged(), isFalse);
    expect(gate.onDetailsVisibilityChanged(false), isTrue);
    expect(gate.onDetailsVisibilityChanged(false), isFalse);
  });

  test('closing an unchanged viewer does not refresh bookmarks', () {
    final gate = BookmarkViewRefreshGate();

    expect(gate.onDetailsVisibilityChanged(true), isFalse);
    expect(gate.onDetailsVisibilityChanged(false), isFalse);
  });
}
