import 'package:equatable/equatable.dart';

final class ApiQuotaKey extends Equatable {
  const ApiQuotaKey._(this.scheme, this.host, this.port);

  factory ApiQuotaKey.fromUri(Uri uri) => ApiQuotaKey._(
    uri.scheme.toLowerCase(),
    uri.host.toLowerCase(),
    uri.port,
  );

  final String scheme;
  final String host;
  final int port;

  @override
  List<Object> get props => [scheme, host, port];

  @override
  String toString() => '$scheme://$host:$port';
}
