// Project imports:
import 'preload_manager.dart';
import 'preload_media.dart';
import 'preload_strategy.dart';

typedef GroupedPreloadMedia<K> = ({K group, PreloadMedia media});

/// Resolves one bounded window, preserving collection indices and authentication
/// groups without retaining a media index for the entire viewer collection.
class GroupedPreloadManager<K extends Object> {
  GroupedPreloadManager({
    required PreloadManager Function(K group) managerBuilder,
  }) : _managerBuilder = managerBuilder;

  final PreloadManager Function(K group) _managerBuilder;
  final _managers = <K, PreloadManager>{};

  void preloadWithStrategy({
    required DirectionBasedPreloadStrategy strategy,
    required int currentPage,
    required int itemCount,
    required GroupedPreloadMedia<K>? Function(int index) mediaBuilder,
  }) {
    final resolved = <int, GroupedPreloadMedia<K>>{};
    for (final index in strategy.getResolutionIndices(
      currentPage: currentPage,
      itemCount: itemCount,
    )) {
      if (mediaBuilder(index) case final media?) {
        resolved[index] = media;
      }
    }

    final groups = resolved.values.map((value) => value.group).toSet();
    for (final group in _managers.keys.toList()) {
      if (!groups.contains(group)) {
        _managers.remove(group)?.cancelAll();
      }
    }

    for (final group in groups) {
      final manager = _managers.putIfAbsent(group, () => _managerBuilder(group));
      manager.preloadWithStrategy(
        strategy: strategy,
        currentPage: currentPage,
        itemCount: itemCount,
        mediaBuilder: (index) {
          final value = resolved[index];
          return value != null && value.group == group ? value.media : null;
        },
      );
    }
  }

  void cancelAll() {
    for (final manager in _managers.values) {
      // Managers can be provider-owned: cancel work, but do not dispose them.
      manager.cancelAll();
    }
    _managers.clear();
  }
}
