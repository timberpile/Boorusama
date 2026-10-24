/// Coalesces one logical selection change (including clear + merge) into one
/// request. An explicit existing search path can win by updating readApplied.
class SearchAutoCommit {
  SearchAutoCommit({
    required this.readQuery,
    required this.readApplied,
    required this.commit,
    required this.schedule,
  });

  final String Function() readQuery;
  final String Function() readApplied;
  final void Function() commit;
  final void Function(void Function()) schedule;
  var _pending = false;
  var _disposed = false;

  void changed() {
    if (_disposed || _pending) return;
    _pending = true;
    schedule(() {
      _pending = false;
      if (!_disposed && readQuery() != readApplied()) commit();
    });
  }

  void dispose() => _disposed = true;
}
