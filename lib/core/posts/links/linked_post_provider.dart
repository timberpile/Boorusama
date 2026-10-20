import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../configs/config/types.dart';
import '../post/providers.dart';
import '../post/types.dart';
import 'boorusama_post_link.dart';

/// Fetch through the recipient's profile, not an HTTP client built from the URI.
final linkedPostProvider = FutureProvider.autoDispose
    .family<Post?, (BoorusamaPostLink, BooruConfig)>((ref, request) async {
      final (link, config) = request;
      if (link.matchingProfiles([config]).isEmpty) return null;
      final result = await ref
          .watch(originAwarePostRepoProvider(config))
          .getPost(link.postId)
          .run();
      return result.fold(
        (error) => throw error,
        (post) => post != null && link.matches(post) ? post : null,
      );
    });
