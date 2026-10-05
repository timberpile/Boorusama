bool isSensitiveAnimeBoxesKey(String key) {
  final canonical = key.toLowerCase().replaceAll(_nonAlphanumeric, '');
  if (_sensitiveExactKeys.contains(canonical)) return true;
  return _sensitiveKeyFragments.any(canonical.contains);
}

final _nonAlphanumeric = RegExp('[^a-z0-9]');

const _sensitiveExactKeys = {
  'auth',
  'key',
  'login',
  'pass',
  'user',
};

const _sensitiveKeyFragments = {
  'apikey',
  'authorization',
  'cookie',
  'credential',
  'password',
  'passwd',
  'secret',
  'token',
  'username',
};
