import 'package:flutter/foundation.dart';

/// Timeline presentation of the global Related preference and raw anchors.
class TimelinePostGrouping extends ChangeNotifier
    implements ValueListenable<bool> {
  Object? _session;

  /// Presentation-only lookup and remembered raw anchor, owned by the grid.
  int Function(int)? representativeIndex;
  int? rawScrollAnchor;
  var _supported = false;
  var _enabled = false;

  bool get supported => _supported;
  Object? get sessionKey => _session;
  @override
  bool get value => _enabled;

  /// The projection owner is already rebuilding when its source changes.
  /// Notify other surfaces after that build, rather than during widget updates.
  bool bind(
    Object session, {
    required bool supported,
    required bool enabled,
  }) {
    final changed =
        _session != session || _supported != supported || _enabled != enabled;
    if (_session != session) {
      rawScrollAnchor = null;
    }
    _session = session;
    _supported = supported;
    _enabled = enabled;
    return changed;
  }

  @override
  void dispose() {
    _session = null;
    representativeIndex = null;
    rawScrollAnchor = null;
    super.dispose();
  }

  void notifySessionChanged() => notifyListeners();
}
