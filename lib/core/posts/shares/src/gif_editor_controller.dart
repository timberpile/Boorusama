import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'gif_conversion_service.dart';
import 'gif_background_execution.dart';
import 'gif_editor_selection.dart';
import 'gif_export_contract.dart';
import 'share_media_preparation.dart';
import 'share_resolution_control.dart';

enum GifEditorPhase { editing, converting, preview, error }

/// Owned by one editor route. Source ownership belongs to the caller; each
/// conversion retains a source owner until all native work has stopped.
class GifEditorController extends ChangeNotifier {
  GifEditorController({
    required this.source,
    required this.service,
    this.background,
  }) : selection = GifEditorSelection.initial(
         source.metadata,
         source.lease.mimeType,
       );

  final GifPreparedSource source;
  final GifConversionService service;
  final GifBackgroundExecution? background;
  GifEditorSelection selection;
  GifEditorPhase phase = GifEditorPhase.editing;
  GifConversionProgress? progress;
  GifConversionException? error;
  ShareMediaLease? result;
  int? resultBytes;
  CancelToken? _token;
  var _closed = false;
  var _changingResult = false;

  void update(GifEditorSelection next) {
    if (_closed || phase != GifEditorPhase.editing) return;
    selection = next;
    notifyListeners();
  }

  Future<void> create() async {
    if (_closed || _changingResult || _token != null || !selection.canCreate) {
      return;
    }
    final token = CancelToken();
    _token = token;
    phase = GifEditorPhase.converting;
    error = null;
    progress = const GifConversionProgress(GifConversionStage.encoding, null);
    notifyListeners();
    ShareMediaLease? output;
    try {
      await background?.start(token);
      checkShareCancellation(token);
      output = await service.convertPrepared(
        source: source,
        settings: selection.settings,
        cancelToken: token,
        onProgress: (value) {
          if (!_closed && !token.isCancelled) {
            progress = value;
            notifyListeners();
          }
        },
      );
      final bytes = await File(output.path).length();
      if (_closed) return;
      if (token.isCancelled) {
        phase = GifEditorPhase.editing;
        return;
      }
      result = output;
      resultBytes = bytes;
      output = null;
      phase = GifEditorPhase.preview;
    } on GifConversionException catch (failure) {
      if (!_closed) {
        if (token.isCancelled ||
            failure.failure == GifConversionFailure.cancelled) {
          phase = GifEditorPhase.editing;
        } else {
          error = failure;
          phase = GifEditorPhase.error;
        }
      }
    } catch (failure) {
      if (!_closed) {
        error = GifConversionException(
          GifConversionFailure.storage,
          cause: failure,
        );
        phase = token.isCancelled
            ? GifEditorPhase.editing
            : GifEditorPhase.error;
      }
    } finally {
      try {
        await output?.release();
      } catch (failure) {
        if (!_closed) {
          error = GifConversionException(
            GifConversionFailure.storage,
            cause: failure,
          );
          phase = GifEditorPhase.error;
        }
      } finally {
        try {
          await background?.stop();
        } catch (failure) {
          // A disappearing engine must not strand Dart ownership or replace
          // the original encode error. Android also stops on engine teardown.
          debugPrint('Could not stop GIF background service: $failure');
        }
        _token = null;
        if (!_closed) notifyListeners();
      }
    }
  }

  void cancel() => _token?.cancel();

  Future<void> adjust() async {
    if (_closed || _token != null || _changingResult) return;
    _changingResult = true;
    final output = result;
    result = null;
    resultBytes = null;
    error = null;
    phase = GifEditorPhase.editing;
    notifyListeners();
    try {
      await output?.release();
    } catch (failure) {
      if (!_closed) {
        error = GifConversionException(
          GifConversionFailure.storage,
          cause: failure,
        );
        phase = GifEditorPhase.error;
      }
    } finally {
      _changingResult = false;
      if (!_closed) notifyListeners();
    }
  }

  Future<void> retrySmaller() async {
    await adjust();
    if (_closed || phase != GifEditorPhase.editing) return;
    final (width, height) = selection.dimensions;
    final edge = width > height ? width : height;
    final smaller = selection.resolutions.where(
      (option) => option.longestEdge != null && option.longestEdge! < edge,
    );
    selection = selection.copyWith(
      resolution: smaller.lastOrNull ?? selection.resolution,
      sourceFrameRate: (source.metadata.frameRate! / 2).floorToDouble().clamp(
        1,
        source.metadata.frameRate!,
      ),
    );
    await create();
  }

  @override
  void dispose() {
    _closed = true;
    cancel();
    final output = result;
    result = null;
    if (output != null) unawaited(output.release());
    super.dispose();
  }
}
