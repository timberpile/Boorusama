// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../downloads/downloader/types.dart';

enum DownloadActivityKind { single, bulk }

enum DownloadActivityPhase {
  preparing,
  queued,
  waitingForWifi,
  running,
  waitingToRetry,
  paused,
  suspended,
  completed,
  skipped,
  failed,
  cancelled,
}

class DownloadActivity extends Equatable {
  const DownloadActivity({
    required this.id,
    required this.kind,
    required this.phase,
    required this.label,
    this.progress,
    this.completedItems,
    this.totalItems,
    this.thumbnailUrl,
    this.error,
    this.startedAt,
    this.completedAt,
    this.completionSource,
  });

  final String id;
  final DownloadActivityKind kind;
  final DownloadActivityPhase phase;
  final String label;
  final double? progress;
  final int? completedItems;
  final int? totalItems;
  final String? thumbnailUrl;
  final String? error;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DownloadCompletionSource? completionSource;

  bool get isTerminal => switch (phase) {
    DownloadActivityPhase.completed ||
    DownloadActivityPhase.skipped ||
    DownloadActivityPhase.failed ||
    DownloadActivityPhase.cancelled => true,
    _ => false,
  };

  @override
  List<Object?> get props => [
    id,
    kind,
    phase,
    label,
    progress,
    completedItems,
    totalItems,
    thumbnailUrl,
    error,
    startedAt,
    completedAt,
    completionSource,
  ];
}
