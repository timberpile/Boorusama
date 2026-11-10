import '../types/viewer_entry.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../boorus/booru/types.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../configs/manage/widgets.dart';
import '../../../../content/content_access.dart';
import '../providers/viewer_source_access_provider.dart';
import '../../../post/providers.dart';
import '../../../post/types.dart';
import '../types/inherited_post.dart';
import '../types/post_presentation_context.dart';
import '../types/post_presentation_fallback_reason.dart';

export '../types/post_presentation_fallback_reason.dart';

final class PostPagePresentation {
  const PostPagePresentation({
    required this.context,
    required this.config,
    required this.fallbackReason,
  });

  final PostPresentationContext context;
  final BooruConfig? config;
  final PostPresentationFallbackReason? fallbackReason;

  bool get usesGenericPresentation => fallbackReason != null;
  BooruConfig get effectiveConfig => config ?? BooruConfig.empty;
}

typedef PostPagePresentationBuilder = Widget Function(
  BuildContext context,
  WidgetRef ref,
  PostPagePresentation presentation,
);

class PostPagePresentationScope extends ConsumerWidget {
  const PostPagePresentationScope({
    required this.post,
    required this.builder,
    this.fallbackConfig,
    this.groupBuilder,
    this.sourceBinding,
    super.key,
  });

  final Post? post;
  final ViewerSourceBinding? sourceBinding;
  final WidgetBuilder? groupBuilder;
  final BooruConfig? fallbackConfig;
  final PostPagePresentationBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binding = sourceBinding;
    final access = binding == null
        ? null
        : ref.watch(viewerSourceAccessProvider(binding));
    final presentation = post == null ? null : _resolve(ref, access);
    final config = presentation?.effectiveConfig ?? BooruConfig.empty;

    return CurrentBooruConfigScope(
      config: config,
      accessKey: access?.key,
      requireAccess: binding != null,
      bookmarkId: binding?.bookmarkId,
      child: InheritedPost(
        presentationContext: presentation?.context,
        child: _PostPagePresentationBuilder(
          presentation: presentation,
          builder: builder,
          groupBuilder: groupBuilder,
        ),
      ),
    );
  }

  PostPagePresentation _resolve(WidgetRef ref, ContentAccessContext? access) {
    final post = this.post!;
    const resolver = PostOriginResolver();
    final profiles = ref.watch(booruConfigProvider);
    final bound = access?.config;
    if (sourceBinding != null && bound == null) {
      return PostPagePresentation(
        context: PostPresentationContext.generic(post),
        config: null,
        fallbackReason: PostPresentationFallbackReason.missingProfile,
      );
    }
    final originResolution = bound?.anonymousReadScope != null
        ? ResolvedPostOrigin(bound!)
        : resolver.resolve(
            post.origin,
            bound == null ? profiles : [bound],
          );
    final resolvedConfig = switch (originResolution) {
      ResolvedPostOrigin(:final config) => config,
      _ => null,
    };
    final config =
        resolvedConfig ??
        (sourceBinding == null ? _resolveFallbackConfig(resolver) : null);
    final originFailure = switch (originResolution) {
      MissingPostOrigin() when config == null =>
        PostPresentationFallbackReason.missingProfile,
      AmbiguousPostOrigin() when config == null =>
        PostPresentationFallbackReason.ambiguousProfile,
      ResolvedPostOrigin() => null,
      _ => null,
    };
    if (originFailure != null) {
      return PostPagePresentation(
        context: PostPresentationContext.resolve(
          post: post,
          presentation: const GenericPostPresentation(),
        ),
        config: null,
        fallbackReason: originFailure,
      );
    }

    final presentationOrigin = resolvedConfig == null
        ? postOriginFromConfig(config!)
        : post.origin;
    final enginePresentation = ref.watch(
      booruPostPresentationProvider(
        PostPresentationRequest(
          origin: presentationOrigin,
          data: post.booruData,
        ),
      ),
    );
    final presentationContext = PostPresentationContext.resolve(
      post: post,
      presentation: enginePresentation,
      resolvedConfig: config,
    );
    final fallbackReason =
        presentationContext.presentation is GenericPostPresentation
        ? _genericFallbackReason(post.booruData)
        : null;

    return PostPagePresentation(
      context: presentationContext,
      config: config,
      fallbackReason: fallbackReason,
    );
  }

  BooruConfig? _resolveFallbackConfig(PostOriginResolver resolver) {
    final fallback = fallbackConfig;
    if (fallback == null) return null;

    if (resolver.resolve(post!.origin, [fallback]) is ResolvedPostOrigin) {
      return fallback;
    }

    final origin = post!.origin;
    final isUnspecified =
        origin.booruType == BooruType.unknown &&
        origin.sourceHost.isEmpty &&
        (origin.profileIdHint == null || origin.profileIdHint == fallback.id);
    return isUnspecified ? fallback : null;
  }
}

PostPresentationFallbackReason _genericFallbackReason(BooruPostData data) =>
    switch (data) {
      UnknownPostData(reason: UnknownPostDataReason.unsupportedVersion) =>
        PostPresentationFallbackReason.unsupportedVersion,
      UnknownPostData(reason: UnknownPostDataReason.malformedData) =>
        PostPresentationFallbackReason.malformedData,
      UnknownPostData(reason: UnknownPostDataReason.unavailableCodec) =>
        PostPresentationFallbackReason.unavailableEngine,
      _ => PostPresentationFallbackReason.incompatiblePresentation,
    };

class _PostPagePresentationBuilder extends ConsumerWidget {
  const _PostPagePresentationBuilder({
    required this.presentation,
    required this.builder,
    this.groupBuilder,
  });

  final WidgetBuilder? groupBuilder;
  final PostPagePresentation? presentation;
  final PostPagePresentationBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => presentation == null
      ? groupBuilder!(context)
      : builder(context, ref, presentation!);
}
