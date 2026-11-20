import 'package:dio/dio.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../../errors/types.dart';
import '../../../../http/client/coordination.dart';
import '../types/favorite_interruption.dart';
import '../types/types.dart';

/// A handled failure or interruption returns null. A completed cleanup
/// interruption still returns the acknowledged action's value.
Future<({T value, bool cleanupInterrupted})?> runFavoriteAction<T>(
  BuildContext context,
  Future<T> Function() action, {
  bool Function()? isCurrent,
}) async {
  final feedbackContext = Scaffold.maybeOf(context)?.context ?? context;
  final ownerRoute = ModalRoute.of(context);
  bool canShowFeedback() =>
      (ownerRoute?.isActive ?? true) && (isCurrent?.call() ?? true);
  FavoriteCompletedWithInterruption? cleanup;
  try {
    final value = await collectFavoriteInterruptions(
      action,
      (e) => cleanup = e,
    );
    if (cleanup != null && feedbackContext.mounted && canShowFeedback()) {
      _showInterruption(feedbackContext, cleanup!.interruption);
    }
    return (value: value, cleanupInterrupted: cleanup != null);
  } on FavoriteActionFailure catch (failure) {
    if (feedbackContext.mounted && canShowFeedback()) {
      showFavoriteActionFailure(feedbackContext, failure);
    }
    return null;
  } on DioException catch (error) {
    if (!isFavoriteRequestInterruption(error)) rethrow;
    if (feedbackContext.mounted && canShowFeedback()) {
      _showInterruption(feedbackContext, error);
    }
    return null;
  }
}

void showFavoriteActionFailure(
  BuildContext context,
  FavoriteActionFailure failure,
) {
  final update = context.t.favorites.update;
  final message = switch (failure) {
    FavoriteActionFailure.unconfirmed => update.failure,
    FavoriteActionFailure.websiteLoginRequired => update.website_login_required,
    FavoriteActionFailure.websiteSessionRejected =>
      update.website_session_rejected,
  };
  Kurumi.showErrorToast(context, message, duration: KurumiDurations.shortToast);
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
