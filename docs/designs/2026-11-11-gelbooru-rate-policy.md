# Gelbooru request-limit audit

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`; external documentation checked 2026-11-11.

## Current configured policy

[ApiQuotaPolicy.forOrigin](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/http/client/src/coordination/api_quota_policy.dart) has no Gelbooru.com-specific branch. The fallback is:

- No server start-rate rule (`serverRules` is empty).
- Up to four in-flight API requests, including at most two passive requests.
- Passive window: 12 starts/minute.
- Bulk window: one start/1250 ms (0.8 requests/second).

Four simultaneous requests is NOT four requests/second and does not enforce the user-reported ten requests/second ceiling for fast interactive calls. [ApiQuotaKey](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/http/client/src/coordination/api_quota_key.dart) keys by scheme, host and port; profiles on the same origin share the coordinator, while aliases are not automatically combined.

[CoordinatedHttpClientAdapter](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/http/client/src/coordination/coordinated_dio.dart) explicitly bypasses API coordination for requests marked as media. [ImageFetcher](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/extended_image/lib/src/image_fetcher.dart) sets that marker. An API policy change alone will not throttle thumbnail CDN traffic or fix the Retry hit-test defect.

## External evidence and limit scope

The user reports an actual account limit of 10 requests/second. The official [account options page](https://gelbooru.com/index.php?page=account&s=options) describes account-specific request limits and a process for requesting an increase; anonymous/indexed output does not establish the numeric value for this account. The official [API wiki](https://gelbooru.com/index.php?id=18780&page=wiki&s=view) documents authentication/throttling and account-dependent exceptions but does not publish a universal ten-per-second contract. Treat ten as the supplied account ceiling, not as an independently verified limit for every account, endpoint or CDN.

## Proposed correction

Add an explicit rolling one-second start window of at most ten API requests for the verified Gelbooru.com API origin, shared across profiles, interactive operations and bulk/passive traffic. Keep existing stricter passive/bulk pacing and the in-flight limit. Ten is a ceiling, not a target throughput; modest headroom can be evaluated separately rather than silently imposing a different purported server limit.

Honor server 429/Retry-After through the existing coordinator and preserve mutation non-replay. Do not apply Gelbooru.com's number to all Gelbooru-engine hosts, image CDNs or arbitrary aliases. If www/non-www share the same evidenced quota, introduce a narrow verified quota alias rather than pooling every subdomain. A configurable server-limit subsystem is unnecessary for this scoped correction.

Test with controlled time: simultaneous requests from two profiles, rolling-window boundary bursts, passive/bulk fairness, cancellation before dispatch, 429 cooldown and mutation safety. Separately evaluate media host concurrency/recovery under the [thumbnail report](2026-11-11-thumbnail-retry.md). No load test against the live service was performed or is recommended merely to discover its limit.
