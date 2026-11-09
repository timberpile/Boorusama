// Project imports:
import '../../../../foundation/loggers/logger.dart';

class LogData {
  const LogData({
    required this.dateTime,
    required this.serviceName,
    required this.safeMessage,
    required this.level,
    this.sensitiveMessage,
    Object? identity,
  }) : _identity = identity;

  final DateTime dateTime;
  final String serviceName;
  final String safeMessage;
  final String? sensitiveMessage;
  final LogLevel level;
  final Object? _identity;
  static final _entryIdentities = Expando<Object>();

  /// The same captured entry keeps its UI state when redaction makes a copy.
  Object get identity => _identity ?? (_entryIdentities[this] ??= Object());

  String get message => sensitiveMessage ?? safeMessage;

  LogData withoutSensitiveDetails() => LogData(
    dateTime: dateTime,
    serviceName: serviceName,
    safeMessage: safeMessage,
    level: level,
    identity: identity,
  );
}
