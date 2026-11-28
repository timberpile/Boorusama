import '../../../../content/content_access.dart';
import 'pixiv_artwork_reference.dart';

/// An in-app artwork reference authorized by a particular Pixiv profile.
typedef NativePixivLookupRequest = ({
  PixivArtworkReference artwork,
  ContentAccessKey sourceAccess,
  int? pageIndex,
});
