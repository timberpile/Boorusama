class BookmarkViewRefreshGate {
  var _detailsVisible = false;
  var _refreshPending = false;

  bool onLibraryChanged() {
    if (!_detailsVisible) return true;

    _refreshPending = true;
    return false;
  }

  bool onDetailsVisibilityChanged(bool visible) {
    _detailsVisible = visible;
    if (visible || !_refreshPending) return false;

    _refreshPending = false;
    return true;
  }
}
