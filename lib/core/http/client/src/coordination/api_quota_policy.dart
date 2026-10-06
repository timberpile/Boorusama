import 'api_quota_key.dart';
import 'api_request_context.dart';

final class ApiRequestDescriptor {
  const ApiRequestDescriptor({
    this.method = 'GET',
    this.path = '/',
    this.replaySafety = ApiReplaySafety.safeRead,
  });
  final String method;
  final String path;
  final ApiReplaySafety replaySafety;
}

final class ApiStartWindow {
  const ApiStartWindow({required this.capacity, required this.duration});
  final int capacity;
  final Duration duration;
  ApiStartWindow buffered(double factor) {
    final rate = capacity * factor;
    return rate >= 1
        ? ApiStartWindow(capacity: rate.floor(), duration: duration)
        : ApiStartWindow(
            capacity: 1,
            duration: Duration(
              microseconds: (duration.inMicroseconds / rate).ceil(),
            ),
          );
  }
}

enum ApiRateScope { all, safeRead, mutation, philomenaSearch }

final class ApiTokenBucket {
  const ApiTokenBucket({required this.capacity, required this.refillPeriod});
  final int capacity;
  final Duration refillPeriod;
}

final class ApiRateRule {
  const ApiRateRule({
    this.scope = ApiRateScope.all,
    this.windows = const [],
    this.bucket,
  });
  final ApiRateScope scope;
  final List<ApiStartWindow> windows;
  final ApiTokenBucket? bucket;
  bool matches(ApiRequestDescriptor descriptor) => switch (scope) {
    ApiRateScope.all => true,
    ApiRateScope.safeRead =>
      descriptor.replaySafety == ApiReplaySafety.safeRead,
    ApiRateScope.mutation =>
      descriptor.replaySafety == ApiReplaySafety.mutation,
    ApiRateScope.philomenaSearch => descriptor.path.startsWith(
      '/api/v1/json/search',
    ),
  };
}

final class ApiQuotaPolicy {
  const ApiQuotaPolicy({
    this.serverRules = const [],
    this.passiveWindow = const ApiStartWindow(
      capacity: 12,
      duration: Duration(minutes: 1),
    ),
    this.maxInFlight = 4,
    this.maxPassiveInFlight = 2,
  });

  /// Explicitly supplied evidenced windows can still request buffering.
  ApiQuotaPolicy.buffered({required List<ApiStartWindow> sourceWindows})
    : serverRules = [
        ApiRateRule(windows: sourceWindows.map((w) => w.buffered(.8)).toList()),
      ],
      passiveWindow = const ApiStartWindow(
        capacity: 12,
        duration: Duration(minutes: 1),
      ),
      maxInFlight = 4,
      maxPassiveInFlight = 2;

  factory ApiQuotaPolicy.forOrigin(ApiQuotaKey key) {
    if (key.scheme != 'https' || key.port != 443) return fallback;
    // https://danbooru.donmai.us/wiki_pages/help:api: 10/s bursts, ~1/s
    // recommended sustained reads. This token bucket implements our pacing,
    // not the server's unpublished global algorithm.
    if (key.host == 'danbooru.donmai.us' || key.host == 'safebooru.donmai.us') {
      return const ApiQuotaPolicy(
        serverRules: [
          ApiRateRule(
            scope: ApiRateScope.safeRead,
            windows: [
              ApiStartWindow(capacity: 10, duration: Duration(seconds: 1)),
            ],
            bucket: ApiTokenBucket(
              capacity: 10,
              refillPeriod: Duration(seconds: 1),
            ),
          ),
          ApiRateRule(
            scope: ApiRateScope.mutation,
            windows: [
              ApiStartWindow(capacity: 1, duration: Duration(seconds: 1)),
            ],
          ),
        ],
      );
    }
    // https://e621.net/help/show/api: hard 2/s; <=1/s recommended.
    if (key.host == 'e621.net' || key.host == 'e926.net') {
      return const ApiQuotaPolicy(
        serverRules: [
          ApiRateRule(
            windows: [
              ApiStartWindow(capacity: 1, duration: Duration(seconds: 1)),
            ],
          ),
        ],
      );
    }
    // https://derpibooru.org/pages/api: general 30/5s, search 20/10s.
    // Exact deployed origin only; other Philomena installations differ.
    if (key.host == 'derpibooru.org') {
      return const ApiQuotaPolicy(
        serverRules: [
          ApiRateRule(
            windows: [
              ApiStartWindow(capacity: 30, duration: Duration(seconds: 5)),
            ],
          ),
          ApiRateRule(
            scope: ApiRateScope.philomenaSearch,
            windows: [
              ApiStartWindow(capacity: 20, duration: Duration(seconds: 10)),
            ],
          ),
        ],
      );
    }
    // https://www.zerochan.net/api: 60/min at the actual API origin.
    if (key.host == 'www.zerochan.net') {
      return const ApiQuotaPolicy(
        serverRules: [
          ApiRateRule(
            windows: [
              ApiStartWindow(capacity: 60, duration: Duration(minutes: 1)),
            ],
          ),
        ],
      );
    }
    return fallback;
  }
  final List<ApiRateRule> serverRules;
  final ApiStartWindow passiveWindow;
  final int maxInFlight;
  final int maxPassiveInFlight;
  static const fallback = ApiQuotaPolicy();
}
