import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'gif_conversion_service.dart';
import 'gif_export_contract.dart';

class GifTimelineStrip {
  const GifTimelineStrip(this.start, this.end, this.bytes);
  final Duration start;
  final Duration end;
  final Uint8List bytes;
}

/// Debounced regional thumbnails with one native writer and a six-strip cache.
/// Cancellation never deletes output or releases the source while native code
/// can still write/read it. A failed request leaves the overview available.
class GifTimelineThumbnails extends ChangeNotifier {
  GifTimelineThumbnails(this.source, this.backend) {
    source.lease.retain();
  }

  final GifPreparedSource source;
  final GifTimelineRegionBackend backend;
  final _cache = <(Duration, Duration), GifTimelineStrip>{};
  Timer? _debounce;
  CancelToken? _active;
  (Duration, Duration)? _wanted;
  Future<void>? _worker;
  Future<void>? _closeFuture;
  var _closed = false;
  GifTimelineStrip? strip;

  void request(Duration start, Duration end) {
    if (_closed || end <= start || _wanted == (start, end)) return;
    _wanted = (start, end);
    _debounce?.cancel();
    _active?.cancel();
    final cached = _cache.remove(_wanted);
    if (cached != null) {
      _cache[_wanted!] = cached;
      strip = cached;
      notifyListeners();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _worker ??= _load().whenComplete(() => _worker = null);
    });
  }

  Future<void> _load() async {
    while (!_closed) {
      final range = _wanted;
      if (range == null || _cache.containsKey(range)) return;
      final token = _active = CancelToken();
      Directory? directory;
      try {
        directory = await File(
          source.lease.path,
        ).parent.createTemp('gif-timeline-');
        final output = File('${directory.path}/strip.png');
        await backend.createTimelineRegion(
          sourcePath: source.lease.path,
          outputPath: output.path,
          start: range.$1,
          duration: range.$2 - range.$1,
          cancelToken: token,
        );
        if (!_closed && !token.isCancelled) {
          final bytes = await output.readAsBytes();
          if (_closed || token.isCancelled) return;
          if (bytes.length > 2 * 1024 * 1024) return;
          final result = GifTimelineStrip(range.$1, range.$2, bytes);
          _cache[range] = result;
          while (_cache.length > 6) {
            _cache.remove(_cache.keys.first);
          }
          if (_wanted == range) {
            strip = result;
            notifyListeners();
          }
        }
      } catch (_) {
        // Thumbnails are optional; the original strip and time ruler remain.
      } finally {
        if (directory != null) {
          try {
            await directory.delete(recursive: true);
          } on FileSystemException {
            // Optional temporary thumbnails can be reclaimed with app cache.
          }
        }
        _active = null;
      }
      if (_wanted == range) return;
    }
  }

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closed = true;
    _debounce?.cancel();
    _active?.cancel();
    try {
      await _worker;
    } finally {
      _cache.clear();
      await source.lease.release();
    }
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
