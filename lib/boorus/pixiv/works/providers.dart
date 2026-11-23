import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/content/content_access.dart';
import '../../../core/content/groups/group_source_provider.dart';
import 'work_source.dart';

/// Compatibility accessor; the registry owns the single actor/source lifetime.
final pixivWorkSourceProvider = Provider.autoDispose
    .family<PixivWorkSource, ContentAccessKey>((ref, key) {
      if (key.engine != BooruType.pixiv || key.profileId == null) {
        throw StateError('Pixiv Work actor unavailable');
      }
      return ref.watch(contentGroupSourceProvider(key)) as PixivWorkSource;
    }, dependencies: [contentGroupSourceProvider]);
