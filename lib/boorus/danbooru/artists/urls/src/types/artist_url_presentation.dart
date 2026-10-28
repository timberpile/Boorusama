enum ArtistUrlPlatform {
  x,
  youtube,
  tiktok,
  threads,
  niconico,
  litLink,
  pixiv,
  web,
}

enum ArtistUrlAccountKind { name, userId, channelId }

typedef ArtistUrlPresentation = ({
  ArtistUrlPlatform platform,
  String platformLabel,
  String account,
  ArtistUrlAccountKind accountKind,
  String url,
});

/// Formats only information present in the URL; never resolves an identity.
ArtistUrlPresentation? artistUrlPresentation(String value) {
  final url = value.trim();
  if (RegExp(r'[\x00-\x20\x7f]|%(?![\da-fA-F]{2})').hasMatch(url)) return null;
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }

  final host = uri.host.toLowerCase();
  bool domain(String name) => host == name || host.endsWith('.$name');
  final List<String> path;
  final Map<String, String> query;
  try {
    path = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    query = uri.queryParameters;
  } on FormatException {
    return null;
  }
  bool number(String value) => RegExp(r'^\d+$').hasMatch(value);
  bool handle(String value) =>
      value.startsWith('@') &&
      value.length > 1 &&
      !RegExp(r'[\s/?#]').hasMatch(value);
  ArtistUrlPresentation account(
    ArtistUrlPlatform platform,
    String label,
    String account, [
    ArtistUrlAccountKind kind = ArtistUrlAccountKind.name,
  ]) => (
    platform: platform,
    platformLabel: label,
    account: account,
    accountKind: kind,
    url: url,
  );

  if (domain('x.com') || domain('twitter.com')) {
    if (path.length == 3 &&
        path[0] == 'i' &&
        path[1] == 'user' &&
        number(path[2])) {
      return account(
        ArtistUrlPlatform.x,
        'X',
        path[2],
        ArtistUrlAccountKind.userId,
      );
    }
    if (path.length == 1 &&
        RegExp(r'^[A-Za-z0-9_]{1,15}$').hasMatch(path[0]) &&
        !{
          'home',
          'explore',
          'search',
          'intent',
          'share',
          'i',
          'settings',
          'messages',
          'notifications',
          'privacy',
          'tos',
          'about',
          'login',
          'signup',
          'compose',
          'download',
          'jobs',
          'hashtag',
        }.contains(path[0].toLowerCase())) {
      return account(ArtistUrlPlatform.x, 'X', '@${path[0]}');
    }
  }
  if (domain('youtube.com')) {
    if (path.length == 1 && handle(path[0])) {
      return account(ArtistUrlPlatform.youtube, 'YouTube', path[0]);
    }
    if (path.length == 2) {
      if (path[0] == 'channel' && RegExp(r'^UC[\w-]+$').hasMatch(path[1])) {
        return account(
          ArtistUrlPlatform.youtube,
          'YouTube',
          path[1],
          ArtistUrlAccountKind.channelId,
        );
      }
      if ({'c', 'user'}.contains(path[0]) &&
          !RegExp(r'[\s/?#]').hasMatch(path[1])) {
        return account(ArtistUrlPlatform.youtube, 'YouTube', path[1]);
      }
    }
  }
  if (path.length == 1 && handle(path[0])) {
    if (domain('tiktok.com')) {
      return account(ArtistUrlPlatform.tiktok, 'TikTok', path[0]);
    }
    if (domain('threads.net') || domain('threads.com')) {
      return account(ArtistUrlPlatform.threads, 'Threads', path[0]);
    }
  }
  if ((domain('nico.ms') || domain('nicovideo.jp')) &&
      path.length == 2 &&
      path[0] == 'user' &&
      number(path[1])) {
    return account(ArtistUrlPlatform.niconico, 'Niconico', path.join('/'));
  }
  if (domain('lit.link') &&
      path.length == 1 &&
      !RegExp(r'[\s/?#]').hasMatch(path[0]) &&
      !{
        'about',
        'contact',
        'signup',
        'terms',
        'privacy',
        'creators',
        'settings',
        'login',
      }.contains(path[0].toLowerCase())) {
    return account(ArtistUrlPlatform.litLink, 'Lit.Link', path[0]);
  }
  if (domain('pixiv.net')) {
    final segments = [...path];
    if (segments.isNotEmpty &&
        RegExp(r'^[a-z]{2}(?:-[a-z]{2})?$').hasMatch(segments.first)) {
      segments.removeAt(0);
    }
    final id = segments.length == 2 && segments[0] == 'users'
        ? segments[1]
        : segments.length == 1 && segments[0] == 'member.php'
        ? query['id']
        : null;
    if (id != null && number(id)) {
      return account(
        ArtistUrlPlatform.pixiv,
        'Pixiv',
        id,
        ArtistUrlAccountKind.userId,
      );
    }
  }

  // Non-profile and unknown URLs stay available without implying an account.
  final shortHost = host.replaceFirst(RegExp(r'^www\.'), '');
  final meaningfulPath = path.join('/');
  final suffix =
      '${uri.hasQuery ? '?${uri.query}' : ''}${uri.hasFragment ? '#${uri.fragment}' : ''}';
  return account(ArtistUrlPlatform.web, shortHost, '$meaningfulPath$suffix');
}

List<String> validArtistProfileUrls(Iterable<String> urls) {
  final seen = <String>{};
  return [
    for (final value in urls)
      if (artistUrlPresentation(value) case final presentation?)
        if (Uri.parse(presentation.url) case final uri
            when seen.add(
              uri
                  .replace(
                    fragment: '',
                    path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
                  )
                  .toString(),
            ))
          presentation.url,
  ];
}
