import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'gif_conversion_service.dart';
import 'gif_background_execution.dart';
import 'gif_editor_selection.dart';
import 'gif_export_contract.dart';
import 'gif_loop_refinement.dart';
import 'gif_loop_refinement_service.dart';
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
    this.loopRefiner,
  }) : selection = GifEditorSelection.initial(
         source.metadata,
         source.lease.mimeType,
       );

  final GifPreparedSource source;
  final GifConversionService service;
  final GifBackgroundExecution? background;
  final GifLoopRefiner? loopRefiner;
  GifEditorSelection selection;
  GifEditorPhase phase = GifEditorPhase.editing;
  GifConversionProgress? progress;
  GifConversionException? error;
  ShareMediaLease? result;
  int? resultBytes;
  CancelToken? _token;
  var _closed = false;
  var _changingResult = false;
  CancelToken? _refineToken;
  Future<void>? _refineJob;
  (Duration, Duration)? _trimUndo;
  GifLoopResult? loopResult;

  bool get isRefining => _refineToken != null;
  bool get showRefineLoop => loopRefiner != null &&
      phase == GifEditorPhase.editing && !gifLoopRequest(selection).isFullSource;
  bool get canUndoRefinement => _trimUndo != null && phase == GifEditorPhase.editing;

  Future<void> refineLoop() async {
    if (_closed || !showRefineLoop || isRefining || !selection.canCreate) return;
    final token = _refineToken = CancelToken();
    final snapshot = selection;
    loopResult = null;
    notifyListeners();
    _refineJob = _refine(snapshot, token);
    await _refineJob;
  }

  Future<void> _refine(GifEditorSelection snapshot, CancelToken token) async {
    try {
      final refined = await loopRefiner!.refine(
        source: source, selection: snapshot, cancelToken: token,
      );
      if (_closed || token.isCancelled || phase != GifEditorPhase.editing ||
          !identical(selection, snapshot)) return;
      loopResult = refined;
      if (refined.matched) {
        final request = gifLoopRequest(snapshot);
        final start = refined.start;
        final end = refined.end;
        // Treat backend output as untrusted and recheck the editor contract.
        if (start == null || end == null ||
            (start - request.start).abs() > request.radius ||
            (end - request.end).abs() > request.radius ||
            start < 0 || end > request.sourceDuration ||
            end - start < request.minimumDuration) {
          loopResult = const GifLoopResult.noMatch();
          return;
        }
        final next = selection.copyWith(
          start: Duration(microseconds: start), end: Duration(microseconds: end),
        );
        if (!next.canCreate) {
          loopResult = const GifLoopResult.noMatch();
          return;
        }
        if (next.start != selection.start || next.end != selection.end) {
          _trimUndo = (selection.start, selection.end);
          selection = next;
        }
      }
    } catch (_) {
      if (!_closed && !token.isCancelled) {
        loopResult = const GifLoopResult.noMatch(GifLoopNoMatchReason.unavailable);
      }
    } finally {
      _refineToken = null;
      _refineJob = null;
      if (!_closed) notifyListeners();
    }
  }

  void cancelRefinement() {
    _refineToken?.cancel();
    loopResult = null;
  }

  void undoRefinement() {
    if (_closed || !canUndoRefinement) return;
    final previous = _trimUndo!;
    final next = selection.copyWith(start: previous.$1, end: previous.$2);
    // Restore the user's trim even if a later FPS change disables conversion.
    update(next);
    _trimUndo = null;
  }

  void update(GifEditorSelection next) {
    if (_closed || phase != GifEditorPhase.editing) return;
    cancelRefinement();
    if (next.start != selection.start || next.end != selection.end) _trimUndo = null;
    selection = next;
    notifyListeners();
  }

  Future<void> create() async {
    // Do not run an analysis decoder and GIF encoder concurrently.
    final refinement = _refineJob;
    if (refinement != null) {
      cancelRefinement();
      await refinement;
    }
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

  void cancel() {
    _token?.cancel();
    cancelRefinement();
  }

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
