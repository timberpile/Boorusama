/// Experimental read-only source foundation. The application engine stays gated
/// until native transport, decoder and shared Gallery/Page acceptance pass.
library;

export 'src/nhentai/client.dart';
export 'src/nhentai/media_policy.dart';
export 'src/nhentai/models.dart'
    show
        NhentaiGallerySummary,
        NhentaiGalleryDetails,
        NhentaiImageDescriptor,
        NhentaiPage,
        NhentaiPageIdentity,
        NhentaiResultPage,
        NhentaiTag;
export 'src/nhentai/tag_cache.dart';
