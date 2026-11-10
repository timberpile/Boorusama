import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../content/anonymous_access_provider.dart';
import '../../../../content/content_access.dart';
import '../../../../content/content_access_provider.dart';
import '../../../post/types.dart';
import '../types/viewer_entry.dart';

/// A binding selects an actor, not the globally selected Browse profile.
final viewerSourceAccessProvider = Provider.autoDispose
    .family<ContentAccessContext?, ViewerSourceBinding>(
      (ref, binding) {
        if (binding.publicOrigin case final origin?) {
          final source = ref
              .watch(anonymousSourcePolicyProvider)
              .forNamespace(
                origin.booruType,
                origin.sourceHost,
              );
          return source == null
              ? null
              : ref.watch(anonymousContentAccessProvider(source));
        }
        final profile = binding.resolve(ref.watch(booruConfigProvider));
        if (profile == null) return null;
        final access = ref.watch(contentProfileAccessProvider(profile.id));
        return access?.config?.auth == profile.auth ? access : null;
      },
      dependencies: [
        booruConfigProvider,
        contentProfileAccessProvider,
        anonymousSourcePolicyProvider,
        anonymousContentAccessProvider,
      ],
    );

ViewerSourceBinding? bindViewerOrigin(
  WidgetRef ref,
  PostOrigin origin, {
  int? bookmarkId,
}) {
  final profiles = ref.read(booruConfigProvider);
  final resolution = const PostOriginResolver().resolve(
    origin,
    profiles,
    // Capture the same fresh actor as the listing; the resulting binding stays
    // strict if that profile is removed or its credentials change afterwards.
    allowProfileHintFallback: true,
  );
  return switch (resolution) {
    ResolvedPostOrigin(:final config) => ViewerSourceBinding(
      config,
      bookmarkId: bookmarkId,
    ),
    AmbiguousPostOrigin() => null,
    MissingPostOrigin() =>
      ref
                  .read(anonymousSourcePolicyProvider)
                  .forNamespace(origin.booruType, origin.sourceHost) ==
              null
          ? null
          : ViewerSourceBinding.publicRead(origin, bookmarkId: bookmarkId),
  };
}
