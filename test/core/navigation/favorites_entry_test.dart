import 'package:boorusama/core/navigation/favorites_entry.dart';
import 'package:boorusama/core/navigation/navigation_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'first entry chooses stored order but never replaces a revoked choice',
    () {
      expect(
        resolveFavoritesEntry(eligibleIds: ['b', 'a']),
        const FavoritesEntry.selected('b'),
      );
      expect(
        resolveFavoritesEntry(
          rememberedProfileId: 'removed',
          eligibleIds: ['b', 'a'],
        ),
        const FavoritesEntry.needsChoice('removed'),
      );
      expect(
        resolveFavoritesEntry(eligibleIds: []),
        const FavoritesEntry.empty(),
      );
      expect(
        resolveFavoritesEntry(rememberedProfileId: 'removed', eligibleIds: []),
        const FavoritesEntry.needsChoice('removed'),
      );
    },
  );
  test(
    'an explicit account alias never falls back to remembered selection',
    () {
      expect(
        resolveFavoritesEntry(
          explicitProfileId: 'a',
          rememberedProfileId: 'b',
          eligibleIds: ['a', 'b'],
        ),
        const FavoritesEntry.selected('a'),
      );
      expect(
        resolveFavoritesEntry(
          explicitProfileId: 'removed',
          rememberedProfileId: 'b',
          eligibleIds: ['b'],
        ),
        const FavoritesEntry.needsChoice('removed'),
      );
    },
  );
  test('independent profile choices and collapsed groups survive changes', () {
    final prefs = NavigationPreferences(
      lastBrowseProfileId: 'a',
      lastFavoritesProfileId: 'b',
      collapsedProfileIds: const {'c'},
    );
    final updated = prefs
        .selectBrowse('d')
        .selectFavorites('e')
        .toggleProfile('f');
    expect(updated.lastBrowseProfileId, 'd');
    expect(updated.lastFavoritesProfileId, 'e');
    expect(updated.collapsedProfileIds, {'c', 'f'});
    expect(prefs.collapsedProfileIds, {'c'});
  });
}
