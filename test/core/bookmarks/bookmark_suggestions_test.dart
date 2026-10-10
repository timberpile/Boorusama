import 'package:boorusama/core/bookmarks/src/providers/suggestion_provider.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/tags/categories/providers.dart';
import 'package:boorusama/core/tags/categories/types.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _TagTypeStore extends Mock implements TagTypeStore {}

void main() {
  test(
    'local suggestions search negative tag names and clear an incomplete token',
    () async {
      final config = BooruConfigAuth.fromConfig(BooruConfig.empty);
      final container = ProviderContainer(
        overrides: [
          sortedTagsProvider.overrideWith(
            (ref) => Future.value(const [
              MapEntry('glasses', 5),
              MapEntry('GLASS', 2),
              MapEntry('hat', 1),
            ]),
          ),
          booruTagTypeStoreProvider.overrideWith(
            (ref) => Future.value(_TagTypeStore()),
          ),
          colorSchemeProvider.overrideWithValue(const ColorScheme.light()),
          booruRepoProvider(config).overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(tagSuggestionsProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(tagSuggestionsProvider.future);
      final notifier = container.read(tagSuggestionsProvider.notifier);
      for (final query in ['gla', 'blue_hair -gla', '-GLA']) {
        await notifier.loadSuggestions(config, query);
        expect(
          container
              .read(tagSuggestionsProvider)
              .requireValue
              .suggestions
              .map((s) => s.tag),
          ['glasses', 'GLASS'],
        );
      }
      await notifier.loadSuggestions(config, 'blue_hair -');
      expect(
        container.read(tagSuggestionsProvider).requireValue.suggestions,
        isEmpty,
      );
    },
  );
}
