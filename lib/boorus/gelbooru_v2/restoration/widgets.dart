// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/position/providers.dart';
import '../../../core/posts/position/types.dart';
import '../../../core/posts/position/widgets.dart';
import '../../../core/search/search/routes.dart';
import '../../../core/search/selected_tags/types.dart';
import '../../../core/settings/providers.dart';
import '../client_provider.dart';
import 'utils.dart';

class GelbooruV2SessionRestorePage extends ConsumerWidget {
  const GelbooruV2SessionRestorePage({
    super.key,
    required this.snapshot,
  });

  final PaginationSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watchConfigSearch;
    final fixedLimit = ref
        .read(gelbooruV2ClientProvider(search.auth))
        .fixedLimit;

    return PageFindingDialog(
      config: PageFinderConfig(
        repository: ref.read(
          defaultPostPageFinderRepoProvider(search),
        ),
        searchChunkSize: fixedLimit ?? 100,
        userChunkSize:
            fixedLimit ??
            ref.read(listingSettingsForAuthProvider(search.auth)).postsPerPage,
      ),
      snapshot: snapshot,
      onSuccess: (location) {
        goToSearchPage(
          ref,
          tag: snapshot.tags,
          queryType: QueryType.simple,
          position: location.index,
          page: location.page,
        );
      },
      paginationLimitView: (context) => PaginationLimitView(
        onContinueBrowsing: () {
          goToSearchPage(
            ref,
            tag: buildIdContinuationQuery(snapshot),
          );
        },
      ),
    );
  }
}
