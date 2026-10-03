import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../foundation/filesystem.dart';
import '../../sources/providers.dart';
import '../export/export_flow_notifier.dart';
import 'nearby_transfer_service.dart';

final nearbyExportServiceProvider = Provider<NearbyExportService>((ref) {
  final sources = ref.watch(exportImportSourcesProvider);
  return NearbyExportService(
    exportService: ref.watch(exportServiceProvider),
    catalog: NearbyExportCatalog([
      for (final source in sources) source.selectionDescriptor,
    ]),
    fs: ref.watch(appFileSystemProvider),
  );
});

final nearbyImportServiceProvider = Provider<NearbyImportService>((ref) {
  return NearbyImportService(
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(minutes: 5),
      ),
    ),
    fs: ref.watch(appFileSystemProvider),
  );
});
