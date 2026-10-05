import '../../../../configs/config/types.dart';

String pinnedSearchProfileCaption(
  BooruConfig profile,
  Iterable<BooruConfig> profiles,
) {
  if (profile.name.isEmpty) return profile.url;
  if (profiles.where((candidate) => candidate.name == profile.name).length ==
      1) {
    return profile.name;
  }
  return '${profile.name} · ${profile.url}';
}
