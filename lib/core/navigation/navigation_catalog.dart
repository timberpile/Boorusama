import 'destination_definition.dart';

final class NavigationCatalog {
  NavigationCatalog({
    required List<ProfileNavigationSection> profileSections,
    required List<GlobalNavigationDefinition> globalEntries,
    required List<String> eligibleFavoritesProfileIds,
  }) : profileSections = List.unmodifiable(profileSections),
       globalEntries = List.unmodifiable(globalEntries),
       eligibleFavoritesProfileIds = List.unmodifiable(
         eligibleFavoritesProfileIds,
       );
  final List<ProfileNavigationSection> profileSections;
  final List<GlobalNavigationDefinition> globalEntries;
  final List<String> eligibleFavoritesProfileIds;
}

/// This projection never constructs pages or starts account discovery.
NavigationCatalog buildNavigationCatalog({
  required List<ProfileNavigationCapabilities> profilesInStoredOrder,
  required List<GlobalNavigationDefinition> globalDefinitions,
}) {
  final eligible = <String>[];
  final sections = <ProfileNavigationSection>[];
  for (final profile in profilesInStoredOrder) {
    if (profile.favorites == NavigationAvailability.available) {
      eligible.add(profile.profileId);
    }
    final rows = profile.tools
        .where(
          (tool) =>
              tool.availability == NavigationAvailability.available &&
              !tool.isUnifiedFavorites &&
              tool.toolId != 'favorites',
        )
        .toList();
    if (rows.isNotEmpty) {
      sections.add(
        ProfileNavigationSection(
          profileId: profile.profileId,
          caption: profile.caption,
          profileIcon: profile.profileIcon,
          rows: rows,
        ),
      );
    }
  }
  var hasFavorites = false;
  final entries = globalDefinitions.where((entry) {
    if (!entry.available) return false;
    if (!entry.isSharedFavorites) return true;
    if (hasFavorites || eligible.isEmpty) return false;
    return hasFavorites = true;
  }).toList();
  return NavigationCatalog(
    profileSections: sections,
    globalEntries: entries,
    eligibleFavoritesProfileIds: eligible,
  );
}
