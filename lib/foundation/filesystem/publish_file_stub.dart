bool publishFileIfAbsent(String source, String destination) =>
    throw UnsupportedError('Atomic file publication requires native storage');

Future<bool> publishFileIfAbsentAsync(
  String source,
  String destination,
) async => publishFileIfAbsent(source, destination);
