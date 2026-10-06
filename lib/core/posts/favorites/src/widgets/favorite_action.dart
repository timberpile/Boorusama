import 'package:dio/dio.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../../errors/types.dart';
import '../../../../http/client/coordination.dart';
import '../types/favorite_interruption.dart';

/// null means the mutation was interrupted before success. A completed cleanup
/// interruption still returns the action's value and runs success callbacks.
Future<({T value, bool cleanupInterrupted})?> runFavoriteAction<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  final feedbackContext = Scaffold.maybeOf(context)?.context ?? context;
  final ownerRoute = ModalRoute.of(context);
  FavoriteCompletedWithInterruption? cleanup;
  try {
    final value = await collectFavoriteInterruptions(
      action,
      (e) => cleanup = e,
    );
    if (cleanup != null &&
        feedbackContext.mounted &&
        (ownerRoute?.isActive ?? true)) {
      _showInterruption(feedbackContext, cleanup!.interruption);
    }
    return (value: value, cleanupInterrupted: cleanup != null);
  } on DioException catch (error) {
    if (!isFavoriteRequestInterruption(error)) rethrow;
    if (feedbackContext.mounted && (ownerRoute?.isActive ?? true)) {
      _showInterruption(feedbackContext, error);
    }
    return null;
  }
}

bool _showInterruption(BuildContext context, DioException error) {
  if (error.type == DioExceptionType.cancel) return true;
  final cooldown = error.error;
  if (cooldown is! ApiCooldownException) return false;
  if (context.mounted) {
    Kurumi.showErrorToast(
      context,
      rateLimitWaitText(context, cooldown.retryAt),
      duration: KurumiDurations.shortToast,
    );
  }
  return true;
}
