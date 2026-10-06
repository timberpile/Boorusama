import 'dart:async';
import 'package:dio/dio.dart';

enum ApiRequestClass {
  interactive,
  userInitiated,
  bulkTransfer,
  automatic,
  preload,
}

enum ApiReplaySafety { safeRead, mutation }

enum ApiAdmissionBehavior { wait, dropIfUnavailable }

const apiRequestContextKey = 'boorusama.request.context';
const apiMediaRequestKey = 'boorusama.request.media';
const apiMutationRequestKey = 'boorusama.request.mutation';
const apiSafeReadRequestKey = 'boorusama.request.safeRead';
const apiRetryKey = 'boorusama.request.retried';
final _contextZoneKey = Object();

final class ApiRequestContext {
  const ApiRequestContext({
    ApiRequestClass requestClass = ApiRequestClass.interactive,
    this.replaySafety,
    this.cancelToken,
    this.canStart,
    this.canAdmit,
    this.onStarted,
    bool allowCooldownRetry = true,
    this.requestClassResolver,
    this.allowCooldownRetryResolver,
    this.onDataTransport,
    this.changes,
    this.admissionBehavior = ApiAdmissionBehavior.wait,
  }) : _requestClass = requestClass,
       _allowCooldownRetry = allowCooldownRetry;

  factory ApiRequestContext.current() =>
      Zone.current[_contextZoneKey] as ApiRequestContext? ??
      const ApiRequestContext();

  final ApiRequestClass _requestClass;
  final ApiRequestClass Function()? requestClassResolver;
  final bool Function()? allowCooldownRetryResolver;
  final void Function(Uri uri, bool running)? onDataTransport;
  final Stream<void>? changes;
  ApiRequestClass get requestClass =>
      requestClassResolver?.call() ?? _requestClass;
  final ApiAdmissionBehavior admissionBehavior;
  final ApiReplaySafety? replaySafety;
  final CancelToken? cancelToken;
  final bool Function()? canStart;
  final bool Function()? canAdmit;
  final void Function()? onStarted;
  final bool _allowCooldownRetry;
  bool get allowCooldownRetry =>
      allowCooldownRetryResolver?.call() ?? _allowCooldownRetry;
  bool get isPassive =>
      requestClass == ApiRequestClass.automatic ||
      requestClass == ApiRequestClass.preload;
}

Future<T> runWithApiRequestContext<T>(
  ApiRequestContext context,
  Future<T> Function() action,
) => runZoned(action, zoneValues: {_contextZoneKey: context});
