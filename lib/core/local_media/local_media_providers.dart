import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_media_enrichment.dart';
import 'local_media_library.dart';
import 'local_media_models.dart';
import 'local_media_reference.dart';

final localMediaAvailableProvider = Provider<bool>(
  (ref) => !kIsWeb && Platform.isAndroid,
);

final localMediaAndroidProvider = Provider<LocalMediaAndroid>(
  (ref) => const LocalMediaAndroid(),
);

final localMediaLibraryProvider = FutureProvider<LocalMediaLibrary?>((
  ref,
) async {
  if (!ref.watch(localMediaAvailableProvider)) return null;
  final android = ref.watch(localMediaAndroidProvider);
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final root = await android.root();
  final library = await LocalMediaLibrary.open(Directory(root));
  if (disposed) {
    await library.close();
    return null;
  }
  ref.onDispose(() => unawaited(library.close()));
  return library;
});

typedef LocalMediaPresentation = ({LocalMediaItem item, File? file});

final localMediaPresentationProvider = StreamProvider.autoDispose
    .family<LocalMediaPresentation?, LocalMediaReference>((
      ref,
      reference,
    ) async* {
      final library = await ref.watch(localMediaLibraryProvider.future);
      if (library == null) {
        yield null;
        return;
      }
      LocalMediaItem? item() => library.find(reference);
      Future<LocalMediaPresentation?> load() async {
        final metadata = item();
        return metadata == null
            ? null
            : (item: metadata, file: await library.resolve(reference));
      }

      // Subscribe before checking the first file so an overlapping mutation
      // invalidates the result even when it commits during that read.
      final changes = StreamController<LocalMediaReference>();
      final subscription = library.changes.listen(changes.add);
      try {
        yield await load();
        await for (final changed in changes.stream) {
          if (changed == reference) yield await load();
        }
      } finally {
        await subscription.cancel();
        unawaited(changes.close());
      }
    });

final localMediaPosterProvider = FutureProvider.autoDispose
    .family<File?, LocalMediaReference>((ref, reference) {
      final android = ref.watch(localMediaAndroidProvider);
      final media = ref
          .watch(localMediaPresentationProvider(reference))
          .valueOrNull;
      if (media == null || media.file == null) return null;
      return android.thumbnail(reference, media.item.format);
    });

class LocalMediaAndroid {
  const LocalMediaAndroid();

  static const _channel = MethodChannel('boorusama/local_media');

  Future<String> root() async => (await _channel.invokeMethod<String>('root'))!;

  Future<bool> pick({required bool folder}) async =>
      await _channel.invokeMethod<bool>('pick', {'folder': folder}) ?? false;

  Future<({int total, int failed, bool limit})> prepare() async {
    final selection = (await _channel.invokeMapMethod<String, Object>(
      'prepare',
    ))!;
    return (
      total: selection['total']! as int,
      failed: selection['failed']! as int,
      limit: selection['limit']! as bool,
    );
  }

  Future<bool> next() async =>
      await _channel.invokeMethod<bool>('next') ?? false;

  Stream<Uint8List> readDocument() async* {
    try {
      await _channel.invokeMethod<void>('open');
      while (true) {
        final bytes = await _channel.invokeMethod<Uint8List>('read');
        if (bytes == null) return;
        if (bytes.isNotEmpty) yield bytes;
      }
    } finally {
      await _channel.invokeMethod<void>('closeDocument');
    }
  }

  Future<LocalMediaProbe> inspect(File file, LocalMediaFormat format) async {
    try {
      final info = (await _channel.invokeMapMethod<String, int>(
        'inspect',
        {'format': format.name},
      ))!;
      return (
        width: info['width']!,
        height: info['height']!,
        durationMs: info['durationMs'],
      );
    } on PlatformException catch (error) {
      if (error.code == 'limit') throw const LocalMediaLimit();
      if (error.code == 'unsupported') throw const LocalMediaUnsupported();
      rethrow;
    }
  }

  Future<File?> thumbnail(
    LocalMediaReference reference,
    LocalMediaFormat format,
  ) async {
    try {
      final path = await _channel.invokeMethod<String>('thumbnail', {
        'sha256': reference.sha256,
        'format': format.extension,
      });
      return path == null ? null : File(path);
    } on PlatformException {
      return null;
    }
  }

  Future<int> thumbnailBytes() async =>
      (await _channel.invokeMethod<int>('thumbnailBytes'))!;

  Future<void> clearThumbnails() =>
      _channel.invokeMethod<void>('clearThumbnails');

  Future<void> cancel() => _channel.invokeMethod<void>('cancel');
  Future<void> finish() => _channel.invokeMethod<void>('finish');
}

class LocalMediaImportProgress {
  const LocalMediaImportProgress({
    this.running = false,
    this.total,
    this.processed = 0,
    this.cancelled = false,
    this.limit = false,
    this.imported = 0,
    this.duplicates = 0,
    this.skipped = 0,
    this.failed = 0,
  });

  final bool running;
  final int? total;
  final int processed;
  final bool cancelled;
  final bool limit;
  final int imported;
  final int duplicates;
  final int skipped;
  final int failed;

  double? get fraction => switch (total) {
    final count? when count > 0 => processed / count,
    _ => null,
  };
  bool get hasSummary => processed > 0 || failed > 0 || cancelled || limit;
}

final localMediaImportProvider =
    NotifierProvider<LocalMediaImportNotifier, LocalMediaImportProgress>(
      LocalMediaImportNotifier.new,
      dependencies: [localMediaEnrichmentServiceProvider],
    );

class LocalMediaImportNotifier extends Notifier<LocalMediaImportProgress> {
  LocalMediaCancellation? _cancellation;
  Timer? _summaryTimer;
  var _disposed = false;

  @override
  LocalMediaImportProgress build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _cancellation?.cancel();
      _summaryTimer?.cancel();
    });
    return const LocalMediaImportProgress();
  }

  void cancel() {
    final cancellation = _cancellation;
    if (cancellation == null || cancellation.isCancelled) return;
    cancellation.cancel();
    ref.read(localMediaAndroidProvider).cancel().ignore();
  }

  Future<void> pickAndImport({required bool folder}) async {
    if (_cancellation != null || ref.read(localMediaClearingProvider)) return;
    _summaryTimer?.cancel();
    final cancellation = _cancellation = LocalMediaCancellation();
    final android = ref.read(localMediaAndroidProvider);
    final budget = LocalMediaImportBudget();
    var imported = 0;
    var duplicates = 0;
    var skipped = 0;
    var failed = 0;
    var limit = false;
    int? total;
    var processed = 0;
    void report(bool running) {
      if (_disposed) return;
      state = LocalMediaImportProgress(
        running: running,
        total: total,
        processed: processed,
        cancelled: cancellation.isCancelled,
        limit: limit,
        imported: imported,
        duplicates: duplicates,
        skipped: skipped,
        failed: failed,
      );
    }

    report(true);
    try {
      final library = await ref.read(localMediaLibraryProvider.future);
      if (_disposed || library == null || !await android.pick(folder: folder)) {
        return;
      }
      if (_disposed || cancellation.isCancelled) return;
      void Function(LocalMediaItem)? onImported;
      try {
        onImported = ref
            .read(localMediaEnrichmentServiceProvider)
            .automaticImporter(library, cancellation);
      } catch (_) {
        // Local import works even when settings or profiles cannot load.
      }
      final selection = await android.prepare();
      total = selection.total;
      failed = selection.failed;
      limit = selection.limit;
      report(true);
      while (!cancellation.isCancelled && processed < selection.total) {
        if (budget.exhausted) {
          limit = true;
          break;
        }
        if (!await android.next() || cancellation.isCancelled) break;
        try {
          final result = await library.import(
            android.readDocument(),
            inspect: android.inspect,
            cancellation: cancellation,
            budget: budget,
            onImported: onImported,
          );
          switch (result) {
            case LocalMediaImportResult.imported:
            case LocalMediaImportResult.repaired:
              imported++;
            case LocalMediaImportResult.duplicate:
              duplicates++;
          }
        } on LocalMediaCancelled {
          break;
        } on LocalMediaUnsupported {
          skipped++;
        } on LocalMediaLimit {
          skipped++;
        } on Exception {
          if (cancellation.isCancelled) break;
          failed++;
        }
        processed++;
        report(true);
      }
    } on Exception {
      if (!cancellation.isCancelled) failed++;
    } finally {
      try {
        await android.finish();
      } on Exception {
        if (!cancellation.isCancelled) failed++;
      } finally {
        _cancellation = null;
        report(false);
        if (!_disposed && state.hasSummary) {
          _summaryTimer = Timer(const Duration(seconds: 6), () {
            state = const LocalMediaImportProgress();
          });
        }
      }
    }
  }
}

final localMediaClearingProvider =
    NotifierProvider<LocalMediaClearingNotifier, bool>(
      LocalMediaClearingNotifier.new,
    );

class LocalMediaClearingNotifier extends Notifier<bool> {
  var _disposed = false;

  @override
  bool build() {
    ref.onDispose(() => _disposed = true);
    return false;
  }

  Future<void> clear() async {
    if (state || ref.read(localMediaImportProvider).running) return;
    state = true;
    final android = ref.read(localMediaAndroidProvider);
    try {
      final library = await ref.read(localMediaLibraryProvider.future);
      if (library == null) return;
      await library.clear();
      await android.clearThumbnails();
    } finally {
      if (!_disposed) state = false;
    }
  }
}
