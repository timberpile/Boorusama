import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access.dart';
import '../../../core/content/content_access_provider.dart';
import '../client_provider.dart';
import 'work_source.dart';

/// Engine-owned preparation for the native Work listing/viewer integration.
/// The existing registry remains the owner of the eventual Group capability.
final pixivWorkSourceProvider = Provider.autoDispose
    .family<PixivWorkSource, ContentAccessKey>(
      (ref, key) {
        final access = ref.watch(contentAccessContextProvider(key));
        final config = access?.config;
        if (access == null ||
            config == null ||
            key.engine != BooruType.pixiv ||
            key.profileId == null ||
            config.anonymousReadScope != null) {
          throw StateError('Pixiv Work actor unavailable');
        }
        final client = ref.watch(pixivClientProvider(config.auth));
        final source = PixivWorkSource(
          access: access,
          blacklist: Set.unmodifiable(
            ref.read(contentEffectiveBlacklistProvider(config.id)).requireValue,
          ),
          fetchWork: (illustId) => client.getIllustDetail(illustId: illustId),
        );
        ref.onDispose(source.dispose);
        return source;
      },
      dependencies: [
        contentAccessContextProvider,
        pixivClientProvider,
        contentEffectiveBlacklistProvider,
      ],
    );
