import 'package:equatable/equatable.dart';

/// Lightweight preferences only; route stacks and durable domain data stay out.
final class NavigationPreferences extends Equatable {
  NavigationPreferences({
    this.lastBrowseProfileId,
    this.localMediaSelected = false,
    this.lastFavoritesProfileId,
    Set<String> collapsedProfileIds = const {},
  }) : collapsedProfileIds = Set.unmodifiable(collapsedProfileIds);
  final String? lastBrowseProfileId;
  final bool localMediaSelected;
  final String? lastFavoritesProfileId;
  final Set<String> collapsedProfileIds;

  NavigationPreferences selectBrowse(String id) => NavigationPreferences(
    lastBrowseProfileId: id,
    lastFavoritesProfileId: lastFavoritesProfileId,
    collapsedProfileIds: collapsedProfileIds,
  );
  NavigationPreferences selectLocalMedia() => NavigationPreferences(
    lastBrowseProfileId: lastBrowseProfileId,
    localMediaSelected: true,
    lastFavoritesProfileId: lastFavoritesProfileId,
    collapsedProfileIds: collapsedProfileIds,
  );
  NavigationPreferences selectFavorites(String id) => NavigationPreferences(
    lastBrowseProfileId: lastBrowseProfileId,
    localMediaSelected: localMediaSelected,
    lastFavoritesProfileId: id,
    collapsedProfileIds: collapsedProfileIds,
  );
  NavigationPreferences toggleProfile(String id) => NavigationPreferences(
    lastBrowseProfileId: lastBrowseProfileId,
    localMediaSelected: localMediaSelected,
    lastFavoritesProfileId: lastFavoritesProfileId,
    collapsedProfileIds: collapsedProfileIds.contains(id)
        ? (Set.of(collapsedProfileIds)..remove(id))
        : {...collapsedProfileIds, id},
  );

  @override
  List<Object?> get props => [
    lastBrowseProfileId,
    localMediaSelected,
    lastFavoritesProfileId,
    collapsedProfileIds,
  ];
}
