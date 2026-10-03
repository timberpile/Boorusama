// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../foundation/data_mutation_coordinator.dart';

// Project imports:
import '../../../../foundation/filesystem.dart';
import '../types/download_repository.dart';
import 'coordinated_download_repository.dart';
import 'repo_empty.dart';

const kDownloadDbName = 'download.db';

final downloadRepositoryProvider = FutureProvider<DownloadRepository>((
  ref,
) async {
  final repo = await ref.watch(internalDownloadRepositoryProvider.future);

  return CoordinatedDownloadRepository(
    repo,
    ref.watch(dataMutationCoordinatorProvider),
  );
});

final internalDownloadRepositoryProvider = FutureProvider<DownloadRepository>(
  (ref) => DownloadRepositoryEmpty(),
);

Future<String> getDownloadsDbPath(AppFileSystem fs) async {
  return '';
}
