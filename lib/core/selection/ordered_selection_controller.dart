// The adapter deliberately uses the registration/drag hooks of the pinned
// selection_mode 0.0.6. The package still owns gestures, haptics and auto-scroll.
// ignore_for_file: invalid_use_of_internal_member, implementation_imports

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:selection_mode/selection_mode.dart';
import 'package:selection_mode/src/core/selection_item_info.dart';

/// Bridges loaded, stable identities to the package's transient index space.
/// Selection lives in the package controller; no second selected-ID set exists.
class OrderedSelectionController<K extends Object>
    extends SelectionModeController {
  OrderedSelectionController({super.initialEnabled});

  List<K> _entries = const [];
  Map<K, int> _indices = const {};
  Object? _scope;
  var _hasScope = false;
  K? _anchor;
  Set<K>? _beforeDrag;
  var _batching = false;
  var _muted = false;
  var _disposed = false;
  var _pendingNotification = false;
  Offset Function(Offset)? dragPositionToLocal;

  @override
  void handleDragUpdate(Offset globalPosition) => super.handleDragUpdate(
    dragPositionToLocal?.call(globalPosition) ?? globalPosition,
  );

  /// Collection order can be derived in a provider-driven build. Reconcile now
  /// so row indices are safe; notify ancestors after that build has finished.
  void reconcileDuringBuild(List<K> entries, {Object? scope}) {
    synchronizeDuringBuild(() => setEntries(entries, scope: scope));
  }

  void synchronizeDuringBuild(VoidCallback update) {
    _muted = true;
    try {
      update();
    } finally {
      _muted = false;
    }
  }

  List<K> get entries => _entries;
  Set<K> get selectedKeys => {
    for (final index in selection)
      if (index >= 0 && index < _entries.length) _entries[index],
  };
  K? get anchor => _anchor;
  int? indexOf(K key) => _indices[key];

  void setEntries(List<K> entries, {Object? scope}) {
    if (_scope == scope && listEquals(entries, _entries)) return;
    final changedScope = _hasScope && _scope != scope;
    final append =
        entries.length >= _entries.length &&
        listEquals(entries.take(_entries.length).toList(), _entries);
    if (!changedScope && append) {
      _scope = scope;
      _hasScope = true;
      final oldLength = _entries.length;
      _entries = List.unmodifiable(entries);
      _indices = {for (var i = 0; i < entries.length; i++) entries[i]: i};
      for (var i = oldLength; i < entries.length; i++) {
        super.register(
          SelectionItemInfo(index: i, identifier: i, isSelectable: true),
        );
      }
      notifyListeners();
      return;
    }
    if (changedScope || !append) cancelDrag();
    final selected = changedScope ? <K>{} : selectedKeys;
    final bounds = Map.of(positionCallbacks);
    final active = isActive && !changedScope;
    _batching = true;
    try {
      super.deselectAll();
      for (var i = 0; i < _entries.length; i++) {
        super.unregister(i);
      }
      _scope = scope;
      _hasScope = true;
      _entries = List.unmodifiable(entries);
      _indices = {for (var i = 0; i < entries.length; i++) entries[i]: i};
      assert(
        _indices.length == entries.length,
        'Selection keys must be unique',
      );
      for (var i = 0; i < entries.length; i++) {
        super.register(
          SelectionItemInfo(
            index: i,
            identifier: i,
            isSelectable: true,
            positionCallback: bounds[i],
          ),
        );
      }
      if (changedScope || !_indices.containsKey(_anchor)) _anchor = null;
      if (changedScope) super.disable();
      if (active) {
        super.selectAll([
          for (final key in selected) ?_indices[key],
        ]);
      }
    } finally {
      _batching = false;
    }
    notifyListeners();
  }

  /// Mounted rows supply geometry only. Unmounting a lazy row cannot remove a
  /// loaded selection, and equal numeric post IDs cannot alias package mappings.
  @override
  void register(SelectionItemInfo info) => super.register(
    SelectionItemInfo(
      index: info.index,
      identifier: info.index,
      isSelectable: info.isSelectable,
      positionCallback: info.positionCallback,
    ),
  );

  @override
  void unregister(int index) {
    final callback = positionCallbacks[index];
    // Old row disposal can follow replacement-row registration in one frame.
    // Remove only dead geometry after layout; never remove the replacement's
    // live callback or the selection of an offscreen loaded entry.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed &&
          identical(positionCallbacks[index], callback) &&
          callback?.call() == null) {
        positionCallbacks.remove(index);
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void enable({List<int>? initialSelected}) {
    if (initialSelected?.lastOrNull case final index?
        when index >= 0 && index < _entries.length) {
      _anchor = _entries[index];
    }
    super.enable(initialSelected: initialSelected);
  }

  @override
  void toggleItem(int item) {
    if (item < 0 || item >= _entries.length) return;
    if (!isSelected(item)) _anchor = _entries[item];
    final batching = _batching;
    _batching = true;
    try {
      super.toggleItem(item);
      if (isActive && selection.isEmpty && _beforeDrag == null) disable();
    } finally {
      _batching = batching;
    }
    notifyListeners();
  }

  void click(int index, {bool range = false, bool additive = false}) {
    if (index < 0 || index >= _entries.length) return;
    if (!isActive) enable();
    final from = _indices[_anchor];
    if (!range || from == null) {
      if (range) {
        super.deselectAll();
        _anchor = _entries[index];
        super.selectAll([index]);
      } else {
        toggleItem(index);
      }
      return;
    }
    if (!additive) super.deselectAll();
    super.selectAll([
      for (
        var i = from < index ? from : index;
        i <= (from > index ? from : index);
        i++
      )
        i,
    ]);
  }

  @override
  void startRangeSelection(int index) {
    _beforeDrag = selectedKeys;
    if (index >= 0 && index < _entries.length) _anchor = _entries[index];
    super.startRangeSelection(index);
  }

  void cancelDrag() {
    final before = _beforeDrag;
    if (before == null) return;
    final batching = _batching;
    _batching = true;
    try {
      super.endRangeSelection();
      _beforeDrag = null;
      super.deselectAll();
      super.selectAll([
        for (final key in before) ?_indices[key],
      ]);
    } finally {
      _batching = batching;
    }
    notifyListeners();
  }

  @override
  void endRangeSelection() {
    final deselecting = _beforeDrag?.isNotEmpty ?? false;
    super.endRangeSelection();
    _beforeDrag = null;
    if (deselecting && isActive && selection.isEmpty) disable();
  }

  @override
  void disable({bool clearSelection = true}) {
    _beforeDrag = null;
    _anchor = null;
    super.disable(clearSelection: clearSelection);
  }

  @override
  void notifyListeners() {
    if (_muted) {
      if (!_pendingNotification) {
        _pendingNotification = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _pendingNotification = false;
          if (!_disposed) notifyListeners();
        });
      }
      return;
    }
    if (!_batching) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
