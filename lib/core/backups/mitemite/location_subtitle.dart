import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../auto/repo_android.dart';

// The caller supplies a location/access generation, not a polling timestamp.
// Recheck the display-only name after relocation or grant loss/recovery.
final miteMiteLocationDisplayProvider = FutureProvider.autoDispose
    .family<String?, (String, Object?)>(
      (ref, input) => AutoBackupRepositoryAndroid.directoryDisplayPath(
        input.$1,
        verifyAccess: true,
      ),
    );

class MiteMiteLocationSubtitle extends ConsumerWidget {
  const MiteMiteLocationSubtitle({
    required this.location,
    required this.lastUpdated,
    super.key,
  });
  final String? location;
  final Object? lastUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
    location == null
        ? context.t.mitemite.not_configured
        : ref
              .watch(
                miteMiteLocationDisplayProvider((location!, lastUpdated)),
              )
              .when(
                data: (value) =>
                    value ?? context.t.mitemite.location_unavailable,
                loading: () => context.t.settings.data_and_storage.loading,
                error: (_, _) => context.t.mitemite.location_unavailable,
              ),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}
