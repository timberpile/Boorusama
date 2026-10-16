import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../types/search_option.dart';

final searchOptionsProvider =
    Provider.family<List<SearchOption>, BooruConfigAuth>((ref, config) {
      final repository = ref
          .watch(booruEngineRegistryProvider)
          .getRepository(config.booruType);
      return switch (repository) {
        final SearchOptionsCapability capability => capability.searchOptions,
        _ => const [],
      };
    });
