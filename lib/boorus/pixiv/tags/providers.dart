// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/tags/autocompletes/types.dart';
import '../client_provider.dart';

final pixivAutocompleteRepoProvider =
    Provider.family<AutocompleteRepository, BooruConfigAuth>((ref, config) {
      final client = ref.watch(pixivClientProvider(config));

      return AutocompleteRepositoryBuilder(
        autocomplete: (query) async {
          final tags = await client.autocomplete(word: query.text);

          return tags
              .where((e) => e.name != null && e.name!.isNotEmpty)
              .map(
                (e) => AutocompleteData(
                  label: e.translatedName ?? e.name!,
                  value: e.name!,
                ),
              )
              .toList();
        },
      );
    });
