import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/suggestions/suggestions_notifier.dart';
import 'package:boorusama/core/tags/autocompletes/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

class _SeededSuggestions extends SuggestionsNotifier {
  @override
  SuggestionsState build(BooruConfigAuth arg) => SuggestionsState(
    suggestions: {
      'one_piece': [AutocompleteData(label: 'One Piece', value: arg.url)].lock,
    }.lock,
  );
}

void main() {
  test(
    'suggestions belong to the exact query and profile, not a global fallback',
    () {
      final first = BooruConfig.defaultConfig(
        booruType: BooruType.danbooru,
        url: 'https://first.example',
        customDownloadFileNameFormat: null,
      ).auth;
      final second = BooruConfig.defaultConfig(
        booruType: BooruType.danbooru,
        url: 'https://second.example',
        customDownloadFileNameFormat: null,
      ).auth;
      final container = ProviderContainer(
        overrides: [
          suggestionsNotifierProvider.overrideWith(_SeededSuggestions.new),
        ],
      );
      addTearDown(container.dispose);
      container.read(fallbackSuggestionsProvider.notifier).state = [
        const AutocompleteData(label: 'Stale', value: 'stale'),
      ].lock;
      expect(
        container.read(suggestionProvider((first, 'one piece'))).single.value,
        first.url,
      );
      expect(
        container.read(suggestionProvider((second, 'one_piece'))).single.value,
        second.url,
      );
      expect(container.read(suggestionProvider((first, 'missing'))), isEmpty);
    },
  );
}
