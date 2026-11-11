# e-shuushuu favicon investigation

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`. User reports generic globe icons across the app. Source routing is confirmed; the exact failed network/decode response was not captured.

## Current path

[ConfigAwareWebsiteLogo](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/config_widgets/website_logo.dart) preserves custom profile icons, handles the Hydrus asset specially, and otherwise delegates to PostSource. [PostSource's explicit overrides](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/sources/src/source.dart) contain several sites but not e-shuushuu. [getFavicon](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/sources/src/source_utils.dart) therefore builds a Google S2 favicon URL instead of reading the site's icon declaration.

[WebsiteLogo](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/widgets/website_logo.dart) renders a globe on missing/error data, allows one network attempt with a five-second timeout and retains failed memory-cache entries. A generic image returned successfully by Google is a different case from this local failure globe; diagnose which is present before blaming decoding. Access-policy rejection and disabled automatic media loading are additional distinct states.

The official homepage was reachable through web research, but the tool could not validate `/favicon.ico` bytes. Do not treat that candidate path, format or MIME type as verified.

## Recommended correction

Resolve a current first-party icon from the official site's actual `rel=icon` declaration, then verify GET, redirect destination, image format and decoding through the app's icon client. Add a narrow shared override for the exact normalized `e-shuushuu.net` host and any independently verified alias. Use a compatible static PNG/ICO rendition or an approved bundled asset when licensing and update ownership permit; do not add an SVG URL to an image decoder without verifying format support.

Put the mapping at the shared source/favicon boundary so Profiles, pickers, navigation and source captions agree. Preserve customIconUrl precedence. Avoid a fix only in the e-shuushuu profile editor or repeated per-screen assets. For the new mapping, compare parsed hosts rather than copying the existing broad `url.contains(...)` pattern; a lookalike host or a path mentioning e-shuushuu must not select its branding. Keep unrelated host-map cleanup out of scope.

Use the dedicated credential-free favicon client and existing cache. A changed canonical icon URL naturally changes cache identity; evict only a stale failed favicon entry where necessary, not all media caches. Ensure anonymous-source icon validation recognizes the same registered mapping, without authorizing imported arbitrary icon URLs.

## Verification

Unit tests for canonical host, verified aliases, case/scheme normalization, lookalikes, unrelated URLs and custom override precedence. Widget tests for successful icon, failed/blocked loading and anonymous access. Verify actual icon bytes decode on Android, then inspect representative shared consumers. Do not claim a transport fix until the original failure or wrong icon response is observed.

No icon asset, mapping or runtime code was changed in this investigation.
