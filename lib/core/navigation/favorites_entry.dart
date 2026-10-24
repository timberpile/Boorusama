import 'package:equatable/equatable.dart';

enum FavoritesEntryKind { selected, needsChoice, empty }

final class FavoritesEntry extends Equatable {
  const FavoritesEntry.selected(String id)
    : kind = FavoritesEntryKind.selected,
      profileId = id;
  const FavoritesEntry.needsChoice(String id)
    : kind = FavoritesEntryKind.needsChoice,
      profileId = id;
  const FavoritesEntry.empty()
    : kind = FavoritesEntryKind.empty,
      profileId = null;
  final FavoritesEntryKind kind;
  final String? profileId;

  @override
  List<Object?> get props => [kind, profileId];
}

FavoritesEntry resolveFavoritesEntry({
  String? explicitProfileId,
  String? rememberedProfileId,
  required List<String> eligibleIds,
}) {
  final requested = explicitProfileId ?? rememberedProfileId;
  if (requested != null) {
    return eligibleIds.contains(requested)
        ? FavoritesEntry.selected(requested)
        : FavoritesEntry.needsChoice(requested);
  }
  return eligibleIds.isEmpty
      ? const FavoritesEntry.empty()
      : FavoritesEntry.selected(eligibleIds.first);
}
