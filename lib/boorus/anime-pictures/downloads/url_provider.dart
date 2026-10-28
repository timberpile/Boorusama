import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/configs/config/types.dart';
import '../client_provider.dart';
import 'file_url_extractor.dart';

final animePicturesDownloadFileUrlExtractorProvider =
    Provider.family<AnimePicturesDownloadFileUrlExtractor, BooruConfigAuth>(
      (ref, config) => AnimePicturesDownloadFileUrlExtractor(
        client: ref.watch(animePicturesClientProvider(config)),
      ),
    );
