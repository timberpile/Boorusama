import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../foundation/riverpod/riverpod.dart';
import '../../../../configs/config/types.dart';
import '../../../../tags/categories/providers.dart';
import '../types/topic_query_display.dart';

/// Query presentation reads only metadata cached for the owning profile.
final topicQueryTagCategoriesProvider = FutureProvider.autoDispose
    .family<Map<String, String>, (BooruConfigAuth, String)>((
      ref,
      params,
    ) async {
      final (auth, query) = params;
      final names = topicQueryDisplayTokens(query)
          .map((token) => token.tagName)
          .whereType<String>()
          .toSet();
      final normalized = {for (final name in names) name.toLowerCase()};
      final cached = <String, String>{};
      var disposed = false;
      ref.onDispose(() => disposed = true);
      await Future.wait(
        normalized.map((name) async {
          try {
            final category = await ref.watch(
              booruTagTypeProvider((auth, name)).future,
            );
            if (category != null &&
                category.trim().toLowerCase() != 'unknown') {
              // Empty is a known default for some engines, such as Philomena.
              // The engine's generator decides whether it has a color.
              cached[name] = category;
            }
          } catch (_) {
            // Missing/unavailable local metadata leaves the tag neutral.
          }
        }),
      );
      if (disposed) return const {};
      ref.cacheFor(const Duration(minutes: 5));
      return {
        for (final name in names)
          if (cached[name.toLowerCase()] case final category?) name: category,
      };
    });
