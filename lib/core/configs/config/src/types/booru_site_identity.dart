String normalizeBooruSiteUrl(String url) {
  final uri = Uri.parse(url);
  return Uri(
    scheme: uri.scheme,
    host: uri.host.toLowerCase(),
    port: uri.hasPort ? uri.port : null,
    path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
  ).toString();
}
