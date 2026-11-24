# Website credential import verification

The importer stages credentials in the current profile draft. The existing
Save action persists the draft.

| Site | Imported credentials | Read-only check |
| --- | --- | --- |
| Gelbooru.com and Rule34.xxx | User ID, existing API key, website session | DAPI post listing |
| Realbooru.com | User ID and website session | Signed-in account page in the login WebView |
| Danbooru and Donmai Safebooru | Username and selected existing API key | Current profile on the same host matches the username |
| e621.net | Username and selected existing API key | Posts API authenticates the key |
| Derpibooru.org | Existing API token | Authenticated user filters |

Realbooru inherits the Gelbooru 0.2 authentication configuration. Its editor
now exposes one website login action. A public DAPI probe returned HTTP 200
with an explicit failure and an indefinite shutdown message. The public
Account Options page showed no API credential field. There is no claim about
what an authenticated Account Options page currently renders.

Public checks on 24 November 2026 found the labeled credential row in Gelbooru's
options page. Gelbooru returned HTTP 401 for anonymous and synthetic invalid
API credentials. Rule34 returned an authentication error in an HTTP 200 JSON
response. The direct host request to Rule34's options page returned HTTP 403.

Realbooru uses the account document rendered by the existing WebView session.
It requires the account page content and rejects the guest notice observed on
the public page. It verifies the cookie pair again before applying the draft.
Realbooru's Prototype.js replaces `Array.from`. On the live Android account
page it reported zero query parameters while direct iteration found the two
expected parameters. The importer now uses direct iteration.

Live Realbooru verification on the Android emulator reproduced the sign-in
error on the baseline APK. The fixed APK opened the preview after a fresh
sign-in. Cancel kept the website open, Extract Credentials reopened the
preview, and Use Credentials updated the draft. After creating the profile
and restarting the app, reopening the saved profile showed Re-Login.

Authenticated device verification remains pending for the other sites. Verify
each site from website sign-in through preview, Save, and reopening the
profile. Confirm the live credential markup and successful read-only check.
Keep real credentials and authenticated page captures out of fixtures and logs.
