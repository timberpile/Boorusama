import 'package:equatable/equatable.dart';

/// Lightweight preferences only; route stacks and durable domain data stay out.
final class NavigationPreferences extends Equatable {
  NavigationPreferences({
    this.lastBrowseProfileId,
    this.lastFavoritesProfileId,
    Set<String> collapsedProfileIds = const {},
  }) : collapsedProfileIds = Set.unmodifiable(collapsedProfileIds);
  final String? lastBrowseProfileId;
  final String? lastFavoritesProfileId;
  final Set<String> collapsedProfileIds;

  NavigationPreferences selectBrowse(String id) => NavigationPreferences(
    lastBrowseProfileId: id,
    lastFavoritesProfileId: lastFavoritesProfileId,
    collapsedProfileIds: collapsedProfileIds,
  );
  NavigationPreferences selectFavorites(String id) => NavigationPreferences(
    lastBrowseProfileId: lastBrowseProfileId,
    lastFavoritesProfileId: id,
    collapsedProfileIds: collapsedProfileIds,
  );
  NavigationPreferences toggleProfile(String id) => NavigationPreferences(
    lastBrowseProfileId: lastBrowseProfileId,
    lastFavoritesProfileId: lastFavoritesProfileId,
    collapsedProfileIds: collapsedProfileIds.contains(id)
        ? (Set.of(collapsedProfileIds)..remove(id))
        : {...collapsedProfileIds, id},
  );

  @override
  List<Object?> get props => [
    lastBrowseProfileId,
    lastFavoritesProfileId,
    collapsedProfileIds,
  ];
}
