import 'package:material_symbols_icons/symbols.dart';
// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:foundation/widgets.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../listing/src/widgets/grid_card_title.dart';

enum PoolGridItemKind { series, collection, related }

extension on PoolGridItemKind {
  String? get iconAsset => switch (this) {
    PoolGridItemKind.series => 'assets/icon/group_series.svg',
    PoolGridItemKind.collection => 'assets/icon/group_collection.svg',
    PoolGridItemKind.related => null,
  };
}

const _badgeCountStyle = TextStyle(
  color: Colors.white,
  fontSize: 11,
  height: 1,
  fontWeight: FontWeight.w700,
);

/// Shared Pool, Series and future Related tile. The trailing corner stays free.
class PoolGridItem extends ConsumerWidget {
  const PoolGridItem({
    required this.image,
    required this.onTap,
    required this.total,
    required this.name,
    this.category,
    this.displayedCount,
    this.kind = PoolGridItemKind.collection,
    this.showKindIcon = true,
    this.sourceIcon,
    this.trailingAction,
    this.padding = const EdgeInsets.all(2),
    super.key,
  });

  final Widget image;
  final void Function() onTap;
  final int? total;

  /// Members represented by this tile within the current timeline.
  final int? displayedCount;
  final String? name;

  /// Localized type text for accessibility; never shown in the compact badge.
  final String? category;
  final PoolGridItemKind kind;
  final bool showKindIcon;
  final Widget? sourceIcon;
  final Widget? trailingAction;
  final EdgeInsetsGeometry padding;

  String? _visibleCount(BuildContext context, double availableWidth) {
    final displayedCount = kind == PoolGridItemKind.related
        ? null
        : this.displayedCount;
    final candidates = <String>[
      if (total != null && displayedCount != null && displayedCount != total)
        '$displayedCount/$total',
      if (total != null) '$total',
      if (total == null && displayedCount != null) '$displayedCount/?',
    ];
    // Prefer the total to the visible subset when tight.
    final availableTextWidth = availableWidth - 8 - (showKindIcon ? 20 : 0);
    if (availableTextWidth <= 0) return null;
    for (final candidate in candidates) {
      final painter = TextPainter(
        text: TextSpan(text: candidate, style: _badgeCountStyle),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final fits = painter.width <= availableTextWidth && painter.height <= 24;
      painter.dispose();
      if (fits) return candidate;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayedCount = kind == PoolGridItemKind.related
        ? null
        : this.displayedCount;
    final typeLabel =
        category ??
        switch (kind) {
          PoolGridItemKind.series => context.t.pool.category.series,
          PoolGridItemKind.collection => context.t.pool.category.collection,
          PoolGridItemKind.related => context.t.post.detail.related_posts,
        };
    final fullCount = total == null
        ? (displayedCount == null ? null : '$displayedCount/?')
        : displayedCount != null && displayedCount != total
        ? '$displayedCount/$total'
        : '$total';
    final spokenLabel = typeLabel + (fullCount == null ? '' : ' · $fullCount');

    return Padding(
      padding: padding,
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: Stack(
                  children: [
                    Positioned.fill(child: image),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          highlightColor: Colors.transparent,
                          splashFactory: FasterInkSplash.splashFactory,
                          splashColor: Colors.black38,
                          onTap: onTap,
                        ),
                      ),
                    ),
                    if (trailingAction case final action?)
                      PositionedDirectional(
                        end: 4,
                        bottom: 4,
                        child: action,
                      ),
                  ],
                ),
              ),
              if (name case final name? when name.isNotEmpty)
                GridCardTitle(name),
            ],
          ),
          PositionedDirectional(
            top: 4,
            start: 4,
            end: 4,
            child: IgnorePointer(
              child: Row(
                children: [
                  if (sourceIcon case final icon?) ...[
                    SizedBox.square(
                      key: const ValueKey('pool-source-icon'),
                      dimension: 24,
                      child: icon,
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (showKindIcon
                      ? kind != PoolGridItemKind.collection ||
                            (total ?? displayedCount ?? 0) >= 2
                      : fullCount != null)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final count = _visibleCount(
                            context,
                            constraints.maxWidth,
                          );
                          if (!showKindIcon && count == null) {
                            return const SizedBox.shrink();
                          }
                          return Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Semantics(
                              container: true,
                              label: spokenLabel,
                              child: ExcludeSemantics(
                                child: Container(
                                  key: const ValueKey('pool-badge'),
                                  height: 24,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xC0000000),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (showKindIcon &&
                                          kind.iconAsset != null)
                                        SvgPicture.asset(
                                          kind.iconAsset!,
                                          key: ValueKey(
                                            'pool-kind-${kind.name}',
                                          ),
                                          width: 16,
                                          height: 16,
                                        )
                                      else if (showKindIcon)
                                        const Icon(
                                          Symbols.photo_library,
                                          key: ValueKey('pool-kind-related'),
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      if (count != null) ...[
                                        if (showKindIcon)
                                          const SizedBox(width: 4),
                                        Text(
                                          count,
                                          style: _badgeCountStyle,
                                          maxLines: 1,
                                          softWrap: false,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
