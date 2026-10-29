import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Names are persistent action IDs, not localized labels or enum indices.
/// Unavailable actions stay in the saved layout when the profile changes.
enum ViewerToolbarAction {
  comments,
  download,
  bookmark,
  favorite,
  share,
  upvote,
  downvote,
  tags,
  browser,
  original,
  slideshow,
  favoriteGroup,
  tagHistory,
}

/// A null Settings.viewerToolbarLayout retains each engine's legacy layout.
/// An explicit empty toolbar is valid: all actions then live in More.
final class ViewerToolbarLayout extends Equatable {
  factory ViewerToolbarLayout({
    required Iterable<ViewerToolbarAction> toolbar,
    Iterable<ViewerToolbarAction> more = const [],
  }) {
    final requested = toolbar.toSet().toList();
    final pinned = requested.take(maxToolbarActions).toList();
    final overflow = <ViewerToolbarAction>{
      ...requested.skip(maxToolbarActions),
      ...more,
      ...ViewerToolbarAction.values,
    }..removeAll(pinned);
    return ViewerToolbarLayout._(
      List.unmodifiable(pinned),
      List.unmodifiable(overflow),
    );
  }

  const ViewerToolbarLayout._(this.toolbar, this.more);

  /// The mockup's starting arrangement is only used after opting in to edit.
  /// Reset removes the override; it does not impose this order on every engine.
  factory ViewerToolbarLayout.editorDefault() => ViewerToolbarLayout(
    toolbar: const [
      ViewerToolbarAction.comments,
      ViewerToolbarAction.download,
      ViewerToolbarAction.bookmark,
      ViewerToolbarAction.favorite,
      ViewerToolbarAction.share,
    ],
  );

  static const maxToolbarActions = 5;
  final List<ViewerToolbarAction> toolbar;
  final List<ViewerToolbarAction> more;

  static ViewerToolbarLayout? tryParse(Object? value) {
    if (value is! Map ||
        value['version'] != 1 ||
        value['toolbar'] is! List ||
        value['more'] is! List) {
      return null;
    }
    Iterable<ViewerToolbarAction> read(List values) sync* {
      for (final value in values) {
        for (final action in ViewerToolbarAction.values) {
          if (value == action.name) {
            yield action;
            break;
          }
        }
      }
    }

    return ViewerToolbarLayout(
      toolbar: read(value['toolbar'] as List),
      more: read(value['more'] as List),
    );
  }

  Map<String, Object> toJson() => {
    'version': 1,
    'toolbar': [for (final action in toolbar) action.name],
    'more': [for (final action in more) action.name],
  };

  /// [index] is an insertion boundary in the destination before removal.
  /// A full toolbar requires an explicit replacement, never silent eviction.
  ViewerToolbarLayout move(
    ViewerToolbarAction action, {
    required bool toToolbar,
    required int index,
  }) {
    if (toToolbar &&
        !toolbar.contains(action) &&
        toolbar.length >= maxToolbarActions) {
      return this;
    }
    final nextToolbar = [...toolbar];
    final nextMore = [...more];
    final target = toToolbar ? nextToolbar : nextMore;
    var destination = index.clamp(0, target.length).toInt();
    final oldIndex = target.indexOf(action);
    if (oldIndex >= 0 && oldIndex < destination) destination--;
    nextToolbar.remove(action);
    nextMore.remove(action);
    target.insert(destination, action);
    return ViewerToolbarLayout(toolbar: nextToolbar, more: nextMore);
  }

  /// Swap an explicit toolbar slot with an action from More. The displaced
  /// action takes its place in More, retaining the rest of both arrangements.
  ViewerToolbarLayout replace(
    ViewerToolbarAction target, {
    required ViewerToolbarAction withAction,
  }) {
    final targetIndex = toolbar.indexOf(target);
    final sourceIndex = more.indexOf(withAction);
    if (targetIndex < 0 || sourceIndex < 0) return this;
    final nextToolbar = [...toolbar]..[targetIndex] = withAction;
    final nextMore = [...more]..[sourceIndex] = target;
    return ViewerToolbarLayout(toolbar: nextToolbar, more: nextMore);
  }

  ViewerToolbarProjection project(
    Set<ViewerToolbarAction> available, {
    required int capacity,
  }) {
    final eligible = toolbar.where(available.contains).toList();
    final count = capacity.clamp(0, eligible.length).toInt();
    // A central contiguous run preserves user ordering. For even/odd ties,
    // the left outer action moves first, matching the approved prototype.
    final start = ((eligible.length - count) / 2).ceil();
    final shown = eligible.sublist(start, start + count);
    final displaced = eligible.where((action) => !shown.contains(action));
    return ViewerToolbarProjection(
      toolbar: List.unmodifiable(shown),
      more: List.unmodifiable([
        ...displaced,
        ...more.where(available.contains),
      ]),
    );
  }

  @override
  List<Object> get props => [toolbar, more];
}

final class ViewerToolbarProjection {
  const ViewerToolbarProjection({required this.toolbar, required this.more});
  final List<ViewerToolbarAction> toolbar;
  final List<ViewerToolbarAction> more;
}

/// Reserve one 48-dp More target and a gap before allocating ordinary actions.
/// Very short panes may show only More; never pass negative counts to a row.
int viewerToolbarCapacity(double width, {double buttonWidth = 48}) {
  if (!width.isFinite) return ViewerToolbarLayout.maxToolbarActions;
  final available = math.max(0.0, width - buttonWidth - 8);
  return (available / (buttonWidth + 8))
      .floor()
      .clamp(0, ViewerToolbarLayout.maxToolbarActions)
      .toInt();
}
