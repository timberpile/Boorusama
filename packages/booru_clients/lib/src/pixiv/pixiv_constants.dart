// Pixiv publishes no public API. Everything below is the official Android
// app's public client identity, reverse-engineered by the community and
// reused by essentially every third-party client (pixivpy, gallery-dl,
// PixEz, ...). It ships inside every APK, so treating it as a secret buys
// nothing; PKCE is the actual protection on the auth flow.
//
// [hashSecret] is only used to compute [X-Client-Hash], which is API
// compatibility obfuscation carried over from the app's release process, NOT
// a security control. Do not "harden" it (e.g. swapping md5 for sha256) —
// that will simply break authentication against the real API.
library;

/// `https://app-api.pixiv.net` — base host for all authenticated API calls.
const kPixivApiBaseUrl = 'https://app-api.pixiv.net';

/// `https://oauth.secure.pixiv.net` — host for the token endpoint.
const kPixivOAuthBaseUrl = 'https://oauth.secure.pixiv.net';

/// Public OAuth client id of the official Android app.
const kPixivClientId = 'MOBrBDS8blbauoSck0ZfDbtuzpyT';

/// Public OAuth client secret of the official Android app.
const kPixivClientSecret = 'lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj';

/// Secret used to derive `X-Client-Hash`. API-compat obfuscation, not a
/// security control — see the file-level comment above.
const kPixivHashSecret =
    '28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c';

/// `User-Agent` sent on every request, matching the official Android app.
const kPixivUserAgent = 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)';

const kPixivAppOs = 'android';
const kPixivAppOsVersion = '11';
const kPixivAppVersion = '5.0.234';

/// `Referer` for app-api calls. Distinct from [kPixivImageReferer] — image
/// hosts (`i.pximg.net`) enforce a different, host-suffix Referer check and
/// need [kPixivImageReferer] instead (consumed by later slices).
const kPixivApiReferer = 'https://app-api.pixiv.net/';

/// `Referer` required by `i.pximg.net` for images/downloads. Exported here
/// for later slices; S1 itself never requests images.
const kPixivImageReferer = 'https://www.pixiv.net/';

/// Redirect URI sent as a form field to the token endpoint. This is NOT the
/// `pixiv://` custom-scheme URI the login webview redirects to — that one is
/// intercepted in-process and never sent over the network.
const kPixivRedirectUri =
    'https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback';

/// Base URL for the PKCE login page shown in a webview.
const kPixivLoginUrlBase = 'https://app-api.pixiv.net/web/v1/login';

/// Earliest date the ranking endpoint accepts. Anything before this 404s.
final kPixivRankingEarliestDate = DateTime.utc(2007, 9, 13);

/// Page size used by every offset-paged endpoint.
const kPixivPageSize = 30;
