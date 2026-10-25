// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../foundation/loggers.dart';
import '../../../../analytics/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../http/client/providers.dart';
import '../../../../settings/providers.dart';
import '../../../filename/providers.dart';
import '../../../urls/providers.dart';
import '../data/providers.dart';
import 'download_notifier.dart';

final sourceDownloadNotifierParamsProvider =
    Provider.family<
      DownloadNotifierParams,
      (BooruConfigAuth, BooruConfigDownload)
    >(
      (ref, params) {
        final (auth, download) = params;
        return (
          auth: auth,
          download: download,
          profileIconUrl: null,
          downloadFileUrlExtractor: ref.watch(
            downloadFileUrlExtractorProvider(auth),
          ),
          observer: ref.watch(
            analyticsDownloadObserverProvider(auth),
          ),
          filenameBuilder: ref.watch(
            downloadFilenameBuilderProvider(auth),
          ),
          canDownloadMultipleFiles: ref.watch(
            downloadMultipleFileCheckProvider(auth),
          ),
          headers: ref.watch(
            httpHeadersProvider(auth),
          ),
          settings: ref.watch(settingsProvider),
          downloader: ref.watch(downloadServiceProvider),
          logger: ref.watch(loggerProvider),
        );
      },
      dependencies: [
        downloadFileUrlExtractorProvider,
        analyticsDownloadObserverProvider,
        downloadFilenameBuilderProvider,
        downloadMultipleFileCheckProvider,
        httpHeadersProvider,
        settingsProvider,
        downloadServiceProvider,
        loggerProvider,
      ],
    );

// Page presentation may override the read-only profile. Keep that icon-only
// dependency out of the global Bookmark library's source download services.
final downloadNotifierParamsProvider =
    Provider.family<
      DownloadNotifierParams,
      (BooruConfigAuth, BooruConfigDownload)
    >(
      (ref, params) {
        final source = ref.watch(sourceDownloadNotifierParamsProvider(params));
        return (
          auth: source.auth,
          download: source.download,
          profileIconUrl: ref.watch(
            currentReadOnlyBooruConfigProvider.select(
              (value) => value.profileIcon?.url,
            ),
          ),
          downloadFileUrlExtractor: source.downloadFileUrlExtractor,
          filenameBuilder: source.filenameBuilder,
          observer: source.observer,
          canDownloadMultipleFiles: source.canDownloadMultipleFiles,
          headers: source.headers,
          settings: source.settings,
          downloader: source.downloader,
          logger: source.logger,
        );
      },
      dependencies: [
        sourceDownloadNotifierParamsProvider,
        currentReadOnlyBooruConfigProvider,
      ],
    );
