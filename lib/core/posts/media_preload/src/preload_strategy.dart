// Dart imports:
import 'dart:math' as math;

// Project imports:
import 'direction_history.dart';
import 'types.dart';

abstract class PreloadStrategy {
  const PreloadStrategy();

  PreloadResult calculatePreload(PreloadContext context);
}

class PreloadStrategyOptions {
  const PreloadStrategyOptions({
    this.defaultPreloadDistance = 1,
    this.lowConfidenceBoost = 0,
    this.mediumConfidenceBoost = 1,
    this.highConfidenceBoost = 2,
  });

  final int defaultPreloadDistance;
  final int lowConfidenceBoost;
  final int mediumConfidenceBoost;
  final int highConfidenceBoost;

  int getConfidenceBoost(DirectionConfidence confidence) =>
      switch (confidence) {
        DirectionConfidence.low => lowConfidenceBoost,
        DirectionConfidence.medium => mediumConfidenceBoost,
        DirectionConfidence.high => highConfidenceBoost,
      };
}

class DirectionBasedPreloadStrategy extends PreloadStrategy {
  const DirectionBasedPreloadStrategy({
    required this.directionHistory,
    this.options = const PreloadStrategyOptions(),
  });

  final DirectionHistory directionHistory;
  final PreloadStrategyOptions options;

  /// The complete set of indices this strategy may inspect. Mixed-profile
  /// viewers resolve this small window once, before dispatching to each manager.
  Set<int> getResolutionIndices({
    required int currentPage,
    required int itemCount,
  }) {
    final nearbyDistance = const RelevanceZones().nearbyDistance;
    final offsets = {
      ..._preloadOffsets(
        directionHistory.scrollDirection,
        directionHistory.confidence,
      ),
      for (var offset = -nearbyDistance; offset <= nearbyDistance; offset++)
        offset,
    };
    return {
      for (final offset in offsets)
        if (currentPage + offset >= 0 && currentPage + offset < itemCount)
          currentPage + offset,
    };
  }

  List<int> _preloadOffsets(
    ScrollDirection direction,
    DirectionConfidence confidence,
  ) {
    final baseDistance = options.defaultPreloadDistance;
    final distance = switch (directionHistory.entryPattern) {
      EntryPattern.direct => 1,
      EntryPattern.initial || EntryPattern.sequential => baseDistance,
      EntryPattern.exploring => math.max(1, baseDistance - 1),
    };
    return _getPreloadOffsets(distance, direction, confidence, options);
  }

  @override
  PreloadResult calculatePreload(PreloadContext context) {
    final direction = directionHistory.scrollDirection;
    final confidence = directionHistory.confidence;

    final prioritizedUrls = <PrioritizedUrl>[];
    final skipUrls = <String>{};

    final currentMedia = context.getMediaItemAt(context.currentPage);
    if (currentMedia != null) {
      skipUrls.addAll(currentMedia.allUrls);
    }

    final offsets = _preloadOffsets(direction, confidence);

    final desiredUrls = <String>{};
    for (final pageOffset in offsets) {
      final index = context.currentPage + pageOffset;
      if (context.isValidIndex(index)) {
        final media = context.getMediaItemAt(index);
        // When user directly jumps to a post, we're unsure if they're actively
        // browsing or just want to view that specific post, so we conservatively
        // preload only thumbnails to minimize bandwidth usage
        final urls = switch ((directionHistory.entryPattern, media)) {
          (EntryPattern.direct, final media?) => {media.thumbnailUrl},
          (_, final media?) => media.allUrls,
          _ => <String>{},
        };
        if (urls.isNotEmpty) {
          desiredUrls.addAll(urls);

          final priority = _calculateStrategyPriority(
            context,
            pageOffset,
            direction,
            confidence,
            index,
          );
          final distanceFromCurrent = context.distanceFrom(index);
          final relevanceZone = context.getRelevanceZone(index);

          for (final url in urls) {
            prioritizedUrls.add(
              PrioritizedUrl(
                url: url,
                priority: priority,
                distance: distanceFromCurrent,
                relevanceZone: relevanceZone,
              ),
            );
          }
        }
      }
    }

    final cancelUrls = _decideCancellations(
      context,
      desiredUrls,
      direction,
      confidence,
    );

    return PreloadResult(
      prioritizedUrls: prioritizedUrls,
      skipUrls: skipUrls,
      cancelUrls: cancelUrls,
    );
  }

  double _calculateStrategyPriority(
    PreloadContext context,
    int pageOffset,
    ScrollDirection direction,
    DirectionConfidence confidence,
    int targetPage,
  ) {
    final distance = pageOffset.abs();
    final scrollSpeed = directionHistory.getScrollSpeed();

    final priority = PriorityCalculator().calculatePriority(
      distance: distance,
      direction: direction,
      confidence: confidence,
      scrollSpeed: scrollSpeed,
      currentPage: context.currentPage,
      targetPage: targetPage,
    );

    return math.max(0.1, priority);
  }

  Set<String> _decideCancellations(
    PreloadContext context,
    Set<String> desiredUrls,
    ScrollDirection direction,
    DirectionConfidence confidence,
  ) {
    final cancelUrls = context.activeDownloads.difference(desiredUrls);
    if (cancelUrls.isEmpty) return cancelUrls;

    // Non-desired downloads outside the nearby zone are always canceled.
    // Inspect only the positions that could retain a download, not the feed.
    final nearbyDistance = const RelevanceZones().nearbyDistance;
    final start = math.max(0, context.currentPage - nearbyDistance);
    final end = math.min(
      context.itemCount - 1,
      context.currentPage + nearbyDistance,
    );
    for (var index = start; index <= end; index++) {
      if (context.getRelevanceZone(index) == RelevanceZone.nearby &&
          confidence == DirectionConfidence.high &&
          _isOppositeDirection(index, context.currentPage, direction)) {
        continue;
      }

      final media = context.getMediaItemAt(index);
      if (media != null) cancelUrls.removeAll(media.allUrls);
      if (cancelUrls.isEmpty) break;
    }

    return cancelUrls;
  }

  bool _isOppositeDirection(
    int activeIndex,
    int currentPage,
    ScrollDirection direction,
  ) {
    final offset = activeIndex - currentPage;
    return switch ((direction, offset)) {
      (ScrollDirection.forward, final o) when o < 0 => true,
      (ScrollDirection.backward, final o) when o > 0 => true,
      _ => false,
    };
  }

  static List<int> _getPreloadOffsets(
    int distance,
    ScrollDirection direction,
    DirectionConfidence confidence,
    PreloadStrategyOptions options,
  ) {
    final offsets = <int>[];

    // Scale directional boost based on confidence
    final directionalBoost = options.getConfidenceBoost(confidence);

    final (startOffset, endOffset) = switch (direction) {
      ScrollDirection.forward => (-distance, distance + directionalBoost),
      ScrollDirection.backward => (-(distance + directionalBoost), distance),
      ScrollDirection.bidirectional => (-distance, distance),
    };

    for (var i = startOffset; i <= endOffset; i++) {
      if (i != 0) offsets.add(i);
    }

    return offsets;
  }
}
