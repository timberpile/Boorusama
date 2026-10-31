// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/widgets.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../themes/theme/types.dart';

class PoolGridItem extends ConsumerWidget {
  const PoolGridItem({
    required this.image,
    required this.onTap,
    required this.total,
    required this.name,
    this.category,
    this.displayedCount,
    super.key,
  });

  final Widget image;
  final void Function() onTap;
  final int? total;

  /// Local projected membership; omitted for full collection/reference cards.
  final int? displayedCount;
  final String? name;
  final String? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(2),
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
                  ],
                ),
              ),
              if (name case final name? when name.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    name.replaceAll('_', ' '),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          Positioned(
            left: 4,
            right: 4,
            top: 4,
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                height: 28,
                decoration: BoxDecoration(
                  color: context.extendedColorScheme.surfaceContainerOverlayDim,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (category != null || total != null)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            [
                              if (category case final value?) value,
                              if (total case final value?)
                                displayedCount != null &&
                                        displayedCount != value
                                    ? '$displayedCount/$value'
                                    : '$value',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: context
                                  .extendedColorScheme
                                  .onSurfaceContainerOverlayDim,
                            ),
                          ),
                        ),
                      ),
                    Icon(
                      Symbols.photo_library,
                      color: context
                          .extendedColorScheme
                          .onSurfaceContainerOverlayDim,
                      fill: 1,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
