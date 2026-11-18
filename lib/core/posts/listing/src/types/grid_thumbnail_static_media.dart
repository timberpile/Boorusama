import '../../../../content/groups/group_cover_aspect_ratios.dart';

/// Static media retained for a saved cover, without inventing Post metadata.
abstract interface class GridThumbnailStaticMedia {
  String get thumbnail;
  String get sample;
  String get original;
  Map<String, String> get variants;
}

/// Optional metadata; old static covers remain valid without it.
abstract interface class GridThumbnailStaticAspectRatios {
  GroupCoverAspectRatios? get aspectRatios;
}
