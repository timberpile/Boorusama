/// Static media retained for a saved cover, without inventing Post metadata.
abstract interface class GridThumbnailStaticMedia {
  String get thumbnail;
  String get sample;
  String get original;
  Map<String, String> get variants;
}
