// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../../booru/types.dart';
import 'booru_builder.dart';
import 'booru_engine.dart';
import 'booru_repository.dart';

final booruEngineRegistryProvider = Provider<BooruEngineRegistry>(
  (ref) {
    throw UnimplementedError();
  },
  name: 'booruEngineRegistryProvider',
);

final booruBuilderProvider = Provider.family<BooruBuilder?, BooruConfigAuth>(
  (ref, config) {
    final booruBuilder = ref
        .watch(booruEngineRegistryProvider)
        .getBuilder(config.booruType);

    return booruBuilder;
  },
  name: 'currentBooruBuilderProvider',
);

final booruRepoProvider = Provider.family<BooruRepository?, BooruConfigAuth>(
  (ref, config) {
    final booruRepo = ref
        .watch(booruEngineRegistryProvider)
        .getRepository(config.booruType);

    return booruRepo;
  },
  name: 'currentBooruRepositoryProvider',
);

final booruPostCapabilityProvider =
    Provider.family<BooruPostCapability<BooruPostData>?, BooruType>((
      ref,
      type,
    ) {
      return ref.watch(booruEngineRegistryProvider).getPostCapability(type);
    }, name: 'booruPostCapabilityProvider');

@immutable
final class PostPresentationRequest {
  const PostPresentationRequest({
    required this.origin,
    required this.data,
  });

  final PostOrigin origin;
  final BooruPostData data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostPresentationRequest &&
          origin.booruType == other.origin.booruType &&
          data.runtimeType == other.data.runtimeType &&
          data.typeKey == other.data.typeKey &&
          data.schemaVersion == other.data.schemaVersion;

  @override
  int get hashCode => Object.hash(
    origin.booruType,
    data.runtimeType,
    data.typeKey,
    data.schemaVersion,
  );
}

final booruPostPresentationProvider =
    Provider.family<BooruPostPresentation, PostPresentationRequest>((
      ref,
      request,
    ) {
      final capability = ref.watch(
        booruPostCapabilityProvider(request.origin.booruType),
      );
      return capability?.presentationFor(request.origin, request.data) ??
          const GenericPostPresentation();
    }, name: 'booruPostPresentationProvider');
