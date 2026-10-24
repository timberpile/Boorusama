import 'package:flutter/widgets.dart';

import 'destination_id.dart';

typedef LocalizedLabel = String Function(BuildContext context);

enum NavigationAvailability {
  available,
  requiresAccount,
  unsupported,
  waitingForAccountMetadata,
}

final class SiteToolDefinition {
  const SiteToolDefinition({
    required this.toolId,
    required this.label,
    required this.icon,
    required this.availability,
    this.isUnifiedFavorites = false,
  });
  final String toolId;
  final LocalizedLabel label;
  final IconData icon;
  final NavigationAvailability availability;
  final bool isUnifiedFavorites;
}

final class ProfileNavigationCapabilities {
  ProfileNavigationCapabilities({
    required this.profileId,
    required this.caption,
    required this.profileIcon,
    required List<SiteToolDefinition> tools,
    required this.favorites,
  }) : tools = List.unmodifiable(tools);
  final String profileId;
  final String caption;
  final String profileIcon;
  final List<SiteToolDefinition> tools;
  final NavigationAvailability favorites;
}

final class ProfileNavigationSection {
  ProfileNavigationSection({
    required this.profileId,
    required this.caption,
    required this.profileIcon,
    required List<SiteToolDefinition> rows,
  }) : rows = List.unmodifiable(rows);
  final String profileId;
  final String caption;
  final String profileIcon;
  final List<SiteToolDefinition> rows;
}

final class GlobalNavigationDefinition {
  const GlobalNavigationDefinition({
    required AppDestination destination,
    required this.label,
    required this.icon,
    this.available = true,
  }) : destination = destination,
       isSharedFavorites = false;
  const GlobalNavigationDefinition.sharedFavorites({
    required this.label,
    required this.icon,
    this.available = true,
  }) : destination = null,
       isSharedFavorites = true;
  final AppDestination? destination;
  final bool isSharedFavorites;
  final LocalizedLabel label;
  final IconData icon;
  final bool available;
}
