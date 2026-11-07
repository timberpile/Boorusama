import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

import '../../boorus/booru/types.dart';
import '../../boorus/engine/providers.dart';
import '../../errors/types.dart';
import '../../http/client/coordination.dart';
import '../content_access.dart';
import '../content_access_provider.dart';
import '../content_reference.dart';
import 'group_capability.dart';
import 'group_details.dart';
import 'group_metadata_codec.dart';
import 'group_source.dart';
import 'group_summary.dart';

final booruGroupCapabilityProvider =
    Provider.family<BooruGroupCapability?, BooruType>(
      (ref, type) =>
          ref.watch(booruEngineRegistryProvider).getGroupCapability(type),
      dependencies: [booruEngineRegistryProvider],
    );

final contentReferenceCodecProvider = Provider<ContentReferenceCodec>((ref) {
  final registry = ref.watch(booruEngineRegistryProvider);
  return ContentReferenceCodec(
    keyCodecFor: (engine) => registry.getGroupCapability(engine)?.keyCodec,
  );
}, dependencies: [booruEngineRegistryProvider]);

final groupMetadataCodecProvider = Provider<GroupMetadataCodec>((ref) {
  final registry = ref.watch(booruEngineRegistryProvider);
  return GroupMetadataCodec(
    references: ref.watch(contentReferenceCodecProvider),
    dataCodecFor: (engine) => registry.getGroupCapability(engine)?.dataCodec,
  );
}, dependencies: [booruEngineRegistryProvider, contentReferenceCodecProvider]);

final contentGroupSourceProvider = Provider.autoDispose
    .family<ContentGroupSource, ContentAccessKey>(
      (ref, key) {
        // Unsupported engines do not prepare policies or clients just to fail later.
        final capability = ref.watch(booruGroupCapabilityProvider(key.engine));
        if (capability == null) throw _unavailable();
        final context = ref.watch(contentAccessContextProvider(key));
        if (context == null) throw _unavailable();
        final source = capability.createSource(context);
        if (!context.hasSameAuthorization(source.access)) {
          source.dispose();
          throw _unavailable();
        }
        ref.onDispose(source.dispose);
        return source;
      },
      dependencies: [
        booruGroupCapabilityProvider,
        contentAccessContextProvider,
      ],
    );

final groupSummaryProvider = FutureProvider.autoDispose
    .family<ContentGroupSummary, GroupMetadataKey>((ref, key) {
      final source = ref.watch(contentGroupSourceProvider(key.access));
      return readGroupSource(
        ref,
        key.access,
        source,
        () => source.loadSummary(key.reference),
      ).then((summary) {
        const ContentReferenceCodec().requireCompatible(
          key.reference,
          summary.reference,
        );
        return summary;
      });
    }, dependencies: [contentGroupSourceProvider]);

final groupDetailsProvider = FutureProvider.autoDispose
    .family<ContentGroupDetails, GroupMetadataKey>((ref, key) {
      final source = ref.watch(contentGroupSourceProvider(key.access));
      return readGroupSource(
        ref,
        key.access,
        source,
        () => source.loadDetails(key.reference),
      ).then((details) {
        const ContentReferenceCodec().requireCompatible(
          key.reference,
          details.summary.reference,
        );
        return details;
      });
    }, dependencies: [contentGroupSourceProvider]);

/// Each observer owns admission/cancellation. Shared-envelope adapters merge
/// those observers through GroupEnvelopeCache rather than borrowing a token.
Future<T> readGroupSource<T>(
  Ref ref,
  ContentAccessKey key,
  ContentGroupSource source,
  TaskEither<BooruError, T> Function() action,
) {
  final token = CancelToken();
  var active = true;
  ref.onDispose(() {
    active = false;
    token.cancel('Group observer disposed');
  });
  bool current() {
    if (!active) return false;
    try {
      return identical(ref.read(contentGroupSourceProvider(key)), source);
      // BooruError is this application's domain failure type despite its base.
      // ignore: avoid_catching_errors
    } on BooruError {
      return false;
    } on FormatException {
      return false;
    }
  }

  return runGroupRead(source, action, token: token, current: current);
}

Future<T> runGroupRead<T>(
  ContentGroupSource source,
  TaskEither<BooruError, T> Function() action, {
  required CancelToken token,
  required bool Function() current,
}) async {
  if (!current()) throw RequestCancelledError();
  final parent = ApiRequestContext.current();
  final observer = CancelToken();
  void cancel() {
    if (!observer.isCancelled) observer.cancel('Group read no longer active');
  }

  unawaited(token.whenCancel.then((_) => cancel()));
  if (parent.cancelToken case final parentToken?) {
    unawaited(parentToken.whenCancel.then((_) => cancel()));
    if (parentToken.isCancelled) cancel();
  }
  if (token.isCancelled) cancel();
  bool admitted() =>
      !observer.isCancelled && current() && (parent.canStart?.call() ?? true);
  final result = await runWithApiRequestContext(
    ApiRequestContext(
      requestClassResolver: () => parent.requestClass,
      replaySafety: ApiReplaySafety.safeRead,
      cancelToken: observer,
      changes: parent.changes,
      canStart: admitted,
      canAdmit: () => admitted() && (parent.canAdmit?.call() ?? true),
      onStarted: parent.onStarted,
      onDataTransport: parent.onDataTransport,
      allowCooldownRetryResolver: () => parent.allowCooldownRetry,
      admissionBehavior: parent.admissionBehavior,
    ),
    () => Future.any<Either<BooruError, T>>([
      action().run(),
      observer.whenCancel.then((_) => throw RequestCancelledError()),
    ]),
  );
  if (!admitted()) throw RequestCancelledError();
  return result.fold((error) => throw error, (value) => value);
}

AppError _unavailable() => AppError(
  type: AppErrorType.loadDataFromServerFailed,
  message: 'Group source unavailable',
);
