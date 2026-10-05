// Input is a validated absolute URL. Like current bookmark identity, ignore
// scheme/default port and retain the non-default authority and installation path.
String migrationSiteNamespace(String url, {bool includePath = true}) {
  final uri = Uri.parse(url);
  final host = uri.host.toLowerCase();
  final authority = uri.hasPort ? '$host:${uri.port}' : host;
  final path = includePath ? uri.path.replaceFirst(RegExp(r'/+$'), '') : '';
  return '$authority$path';
}

String migrationProfileUrl(String url) {
  final uri = Uri.parse(url);
  return Uri(
    scheme: uri.scheme.toLowerCase(),
    host: uri.host.toLowerCase(),
    port: uri.hasPort ? uri.port : null,
    path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
  ).toString();
}
