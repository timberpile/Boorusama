import '../types/safebooru_pool_availability.dart';

// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/posts/pools/widgets.dart';
import '../../../details/routes.dart';
import '../../providers.dart';
import '../../types.dart';
import 'pool_image.dart';

class PoolPagedSliverGrid extends ConsumerWidget {
  const PoolPagedSliverGrid({
    required this.constraints,
    required this.order,
    required this.category,
    super.key,
    this.name,
    this.description,
  });

  final BoxConstraints constraints;
  final DanbooruPoolOrder order;
  final DanbooruPoolCategory category;
  final String? name;
  final String? description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = poolCoverSearch(ref.watch);
    final safe = isDonmaiSafebooru(config.auth.url);
    if (safe) ref.watch(danbooruPoolCoversProvider(config));
    return PoolPagedSliverGridView<DanbooruPool>(
      fetchRawPage: !safe
          ? null
          : (ref, page) async {
              final repo = ref.read(danbooruPoolRepoProvider(config.auth));
              final covers = ref.read(
                danbooruPoolCoversProvider(config).notifier,
              );
              var rawPage = page;
              for (var attempt = 0; attempt < 2; attempt++) {
                final raw = await repo.getPools(
                  rawPage,
                  category: category,
                  order: order,
                  name: name,
                  description: description,
                );
                await covers.load(raw);
                final visible = raw
                    .where(
                      (pool) =>
                          covers.assessment(pool)?.availability !=
                          PoolAvailability.provenEmpty,
                    )
                    .toList();
                final next = raw.isEmpty ? null : rawPage + 1;
                if (visible.isNotEmpty || next == null || attempt == 1)
                  return PoolDiscoveryPage(visible, next);
                rawPage++;
              }
              throw StateError('Unreachable Pool continuation');
            },
      constraints: constraints,
      refreshKey: (config, order, category, name, description),
      fetchPage: (ref, pageKey) async {
        final config = ref.readConfigSearch;
        final repo = ref.read(danbooruPoolRepoProvider(config.auth));
        final newItems = await repo.getPools(
          pageKey,
          category: category,
          order: order,
          name: name,
          description: description,
        );

        unawaited(
          ref.read(danbooruPoolCoversProvider(config).notifier).load(newItems),
        );

        return newItems;
      },
      imageBuilder: (context, pool) => PoolImage(pool: pool),
      onTap: goToPoolDetailPage,
      total: (pool) => safe
          ? ref
                .read(danbooruPoolCoversProvider(config).notifier)
                .assessment(pool)
                ?.accessibleCount
          : pool.postCount,
      name: (pool) => pool.name,
      kind: (pool) => pool.category == DanbooruPoolCategory.series
          ? PoolGridItemKind.series
          : PoolGridItemKind.collection,
    );
  }
}
