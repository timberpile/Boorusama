import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/search/suggestions/selected_tag_suggestions.dart';
import 'package:boorusama/core/tags/autocompletes/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final query in ['blue_hair', '-blue_hair', '~blue_hair', 'Blue Hair']) {
    test('omits the selected ordinary identity for $query', () {
      final result = withoutSelectedTagSuggestions(
        suggestions: const [
          AutocompleteData(label: 'Blue hair', value: 'blue_hair'),
          AutocompleteData(label: 'Blue eyes', value: 'blue_eyes'),
          AutocompleteData(label: 'Long blue hair', value: 'long_blue_hair'),
        ],
        selectedTags: [TagSearchItem.fromString(query)],
      );
      expect(result.map((tag) => tag.value), ['blue_eyes', 'long_blue_hair']);
    });
  }

  test('uses canonical values and explicit aliases rather than labels', () {
    final result = withoutSelectedTagSuggestions(
      suggestions: const [
        AutocompleteData(label: 'Different label', value: 'cat'),
        AutocompleteData(
          label: 'Canonical',
          value: 'cat',
          type: AutocompleteData.alias,
          antecedent: 'kitty',
        ),
        AutocompleteData(label: 'kitty', value: 'dog'),
      ],
      selectedTags: [TagSearchItem.fromString('-kitty')],
    );
    expect(result.map((tag) => tag.value), ['dog']);
  });

  for (final reversed in [false, true]) {
    for (final selected in ['cat', '-kitty', '~kitten']) {
      test(
        'resolves alias chains and cycles for $selected, reversed=$reversed',
        () {
          const suggestions = [
            AutocompleteData(label: 'Cat', value: 'cat'),
            AutocompleteData(
              label: 'Kitten',
              value: 'kitten',
              type: AutocompleteData.alias,
              antecedent: 'kitty',
            ),
            AutocompleteData(
              label: 'Cat',
              value: 'cat',
              type: AutocompleteData.alias,
              antecedent: 'kitten',
            ),
            AutocompleteData(
              label: 'Kitty',
              value: 'kitty',
              type: AutocompleteData.alias,
              antecedent: 'cat',
            ),
            AutocompleteData(label: 'Dog', value: 'dog'),
          ];
          final result = withoutSelectedTagSuggestions(
            suggestions: reversed ? suggestions.reversed : suggestions,
            selectedTags: [TagSearchItem.fromString(selected)],
          );
          expect(result.map((tag) => tag.value), ['dog']);
        },
      );
    }
  }

  test(
    'does not equate spelling corrections with explicitly selected tags',
    () {
      const suggestions = [
        AutocompleteData(
          label: 'Cat',
          value: 'cat',
          type: AutocompleteData.autoCorrect,
          antecedent: 'cta',
        ),
      ];
      expect(
        withoutSelectedTagSuggestions(
          suggestions: suggestions,
          selectedTags: [TagSearchItem.fromString('cta')],
        ),
        suggestions,
      );
    },
  );

  test('keeps account, pool and supported option suggestions', () {
    const suggestions = [
      AutocompleteData(
        label: 'cat account',
        value: 'cat',
        type: AutocompleteData.user,
      ),
      AutocompleteData(
        label: 'cat pool',
        value: 'cat',
        type: AutocompleteData.pool,
      ),
      AutocompleteData(label: 'Order', value: 'order:score'),
      AutocompleteData(label: 'cat', value: 'cat', type: AutocompleteData.tag),
    ];
    final result = withoutSelectedTagSuggestions(
      suggestions: suggestions,
      selectedTags: [
        TagSearchItem.fromString('cat'),
        TagSearchItem.fromString('order:score'),
      ],
      optionKeys: {'order'},
    );
    expect(result, suggestions.take(3));
  });

  test('does not guess the meaning of raw query fragments', () {
    const suggestions = [AutocompleteData(label: 'cat', value: 'cat')];
    expect(
      withoutSelectedTagSuggestions(
        suggestions: suggestions,
        selectedTags: const [TagSearchItem.raw(tag: 'cat ~dog')],
      ),
      suggestions,
    );
  });

  test(
    'recomputes from the current selection without retaining exclusions',
    () {
      const suggestions = [
        AutocompleteData(label: 'cat', value: 'cat'),
        AutocompleteData(
          label: 'cat',
          value: 'cat',
          type: AutocompleteData.alias,
          antecedent: 'kitty',
        ),
      ];
      final selected = [TagSearchItem.fromString('-kitty')];
      expect(
        withoutSelectedTagSuggestions(
          suggestions: suggestions,
          selectedTags: selected,
        ),
        isEmpty,
      );
      selected.clear();
      expect(
        withoutSelectedTagSuggestions(
          suggestions: suggestions,
          selectedTags: selected,
        ),
        suggestions,
      );
    },
  );
}
