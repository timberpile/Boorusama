# Rule34 favorite mutation investigation

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`. The user reports failure. No authenticated request was executed and the actual HTTP status/body was not supplied, so a single live root cause is NOT established.

## Current implementation

[GelbooruV2Client](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/booru_clients/lib/src/gelbooru_v2/gelbooru_v2_client.dart) uses API user ID/key for its configured read endpoints, but inherits the separate [GelbooruClientFavorites](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/booru_clients/lib/src/gelbooru/gelbooru_client_favorites.dart) mutation implementation:

- `canFavorite` checks only non-null userId/passHash, not nonempty values or session validity.
- Add uses GET `/public/addfav.php?id=...` with `user_id` and `pass_hash` cookies from [buildGelbooruSessionHeaders](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/booru_clients/lib/src/gelbooru/gelbooru_session.dart).
- It accepts only exact String bodies `1`, `2`, `3`; whitespace, numeric responses, login HTML and changed response formats become unknown.
- Both GET mutations are correctly marked `stateChangingRequestExtra`; preserve that non-replay classification.
- Removal accepts HTTP 200/302 without validating the outcome. The [repository](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/boorus/gelbooru_v2/favorites/providers.dart) maps any normal completion to success. A login redirect or failure page must not be reported as a confirmed removal.

[GelbooruV2AuthView](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/boorus/gelbooru_v2/configs/widgets.dart) already distinguishes basic API credentials from AdvancedAuthSection. Successful Browse/API authentication therefore does not prove a valid write session. #159's website credential import is related, but fixing a mutation must not depend on completing that convenience feature.

## Concrete diagnosis and correction

Use the current profile in a local authenticated test, with a disposable/approved Post: compare the website's add request with the app's endpoint, source host, method, cookie names, required CSRF/origin headers and response contract. Record only sanitized status, final host, redirect category, content type and an allowlisted response category; never session values or arbitrary response HTML. Do not issue trial mutations repeatedly or probe anti-bot workarounds.

Distinguish four cases: missing/expired write-session cookies; server restriction/challenge; wrong endpoint/request contract; correct mutation with misparsed response. The inspected source cannot choose between them without the response.

Implement the smallest verified site-specific correction. Keep the existing mixin only where the actual contract is shared; a narrow Rule34 mutation adapter/capability is preferable to changing every Gelbooru host based on one site's behavior. Normalize known success tokens with explicit type/whitespace handling, but do not treat arbitrary 200 HTML or redirects as success. Reject empty credentials and surface a localized reconnect-session action for authentication failures. Never generate/rotate API keys as a repair.

Update local favorite state and Favorites Sync only after a confirmed remote outcome. Preserve prior state on failure; serialize/coalesce repeated user actions, and do not automatically retry mutations whose outcome is uncertain. Validate removal as well as addition; account switches must discard stale completions.

## Tests and remaining acceptance

Client fixtures for each verified response code/type, whitespace, login HTML, redirects, 401/403/429, expired/blank cookies and no automatic mutation replay. Repository tests for failed add/remove preserving state and sync memberships, duplicate actions and account switches. Final authenticated Android add -> verify -> remove -> verify round trip is required; test records must be restored. No runtime implementation or device test was performed by this report.
