// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../configs/manage/widgets.dart';
import '../../../post/types.dart';
import '../types/inherited_post.dart';
import '../types/post_presentation_context.dart';

enum PostPresentationFallbackReason {
  missingProfile,
  ambiguousProfile,
  unavailableEngine,
  malformedData,
  unsupportedVersion,
  removedUpstreamPost,
  refreshFailed,
  incompatiblePresentation,
}

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

typedef PostPagePresentationBuilder =
    Widget Function(
      BuildContext context,
      WidgetRef ref,
      PostPagePresentation presentation,
    );

class PostPagePresentationScope extends ConsumerWidget {
  const PostPagePresentationScope({
    required this.post,
    required this.builder,
    super.key,
  });

  final Post post;
  final PostPagePresentationBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presentation = _resolve(ref);
    final config = presentation.effectiveConfig;

    return CurrentBooruConfigScope(
      config: config,
      child: InheritedPost(
        presentationContext: presentation.context,
        child: _PostPagePresentationBuilder(
          presentation: presentation,
          builder: builder,
        ),
      ),
    );
  }

  PostPagePresentation _resolve(WidgetRef ref) {
    final originResolution = const PostOriginResolver().resolve(
      post.origin,
      ref.watch(booruConfigProvider),
    );
    final config = switch (originResolution) {
      ResolvedPostOrigin(:final config) => config,
      _ => null,
    };
    final originFailure = switch (originResolution) {
      MissingPostOrigin() => PostPresentationFallbackReason.missingProfile,
      AmbiguousPostOrigin() => PostPresentationFallbackReason.ambiguousProfile,
      ResolvedPostOrigin() => null,
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

    final enginePresentation = ref.watch(
      booruPostPresentationProvider((
        origin: post.origin,
        data: post.booruData,
      )),
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
  });

  final PostPagePresentation presentation;
  final PostPagePresentationBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      builder(context, ref, presentation);
}
